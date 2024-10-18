#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#include <sched.h>
#include <pthread.h>
#include <signal.h>
#include <arm_neon.h>

#define BCM2711_PERI_BASE 0xFE000000
#define GPIO_BASE (BCM2711_PERI_BASE + 0x200000)
#define DMA_BASE (BCM2711_PERI_BASE + 0x007000)
#define PWM_BASE (BCM2711_PERI_BASE + 0x20C000)
#define PWM_CLK_BASE (BCM2711_PERI_BASE + 0x101000)

#define PAGE_SIZE (4*1024)
#define BLOCK_SIZE (4*1024)

#define DMA_CS        (0x00/4)
#define DMA_CONBLK_AD (0x04/4)
#define DMA_TI        (0x08/4)
#define DMA_SOURCE_AD (0x0c/4)
#define DMA_DEST_AD   (0x10/4)
#define DMA_TXFR_LEN  (0x14/4)
#define DMA_STRIDE    (0x18/4)
#define DMA_NEXTCONBK (0x1c/4)
#define DMA_DEBUG     (0x20/4)

#define DMA_CHANNEL 5

#define PWM_CTL  (0x00/4)
#define PWM_STA  (0x04/4)
#define PWM_DMAC (0x08/4)
#define PWM_RNG1 (0x10/4)
#define PWM_DAT1 (0x14/4)
#define PWM_FIF1 (0x18/4)

#define PWMCLK_CNTL (40)
#define PWMCLK_DIV  (41)

#define CACHE_LINE_SIZE 64
#define BUFFER_SIZE (1024 * 16)  // 16KB, multiplo della dimensione della cache L1
#define NUM_BUFFERS 2
#define NSEC_PER_SEC 1000000000L

struct DMAControlBlock {
    uint32_t ti;
    uint32_t source_ad;
    uint32_t dest_ad;
    uint32_t txfr_len;
    uint32_t stride;
    uint32_t nextconbk;
    uint32_t reserved[2];
};

volatile unsigned *gpio;
volatile unsigned *dma;
volatile unsigned *pwm;
volatile unsigned *pwm_clk;

void *gpio_map;
void *dma_map;
void *pwm_map;
void *pwm_clk_map;

uint32_t input_buffer[NUM_BUFFERS][BUFFER_SIZE] __attribute__((aligned(CACHE_LINE_SIZE)));
uint32_t output_buffer[NUM_BUFFERS][BUFFER_SIZE] __attribute__((aligned(CACHE_LINE_SIZE)));

struct DMAControlBlock cb[NUM_BUFFERS] __attribute__((aligned(32)));
volatile sig_atomic_t running = 1;
unsigned long long total_cycles = 0;
struct timespec start_time, end_time;

// Dichiarazioni di funzione
void setup_io(void);
void setup_pwm(void);
void setup_dma(void);
void process_data(void);
void set_realtime_priority(void);
void set_cpu_affinity(void);
static uintptr_t get_physical_address(volatile void* addr);
void *process_data_thread(void *arg);

static uintptr_t get_physical_address(volatile void* addr) {
    return ((uintptr_t)addr & 0x3FFFFFFF);
}

void setup_io(void) {
    int mem_fd;
    if ((mem_fd = open("/dev/mem", O_RDWR|O_SYNC)) < 0) {
        perror("Can't open /dev/mem");
        exit(1);
    }

    gpio_map = mmap(NULL, BLOCK_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, mem_fd, GPIO_BASE);
    dma_map = mmap(NULL, BLOCK_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, mem_fd, DMA_BASE);
    pwm_map = mmap(NULL, BLOCK_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, mem_fd, PWM_BASE);
    pwm_clk_map = mmap(NULL, BLOCK_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, mem_fd, PWM_CLK_BASE);

    close(mem_fd);

    if (gpio_map == MAP_FAILED || dma_map == MAP_FAILED || pwm_map == MAP_FAILED || pwm_clk_map == MAP_FAILED) {
        perror("mmap error");
        exit(1);
    }

    gpio = (volatile unsigned *)gpio_map;
    dma = (volatile unsigned *)dma_map;
    pwm = (volatile unsigned *)pwm_map;
    pwm_clk = (volatile unsigned *)pwm_clk_map;
}

void setup_pwm(void) {
    *(pwm + PWM_CTL) = 0;
    while (*(pwm + PWM_STA) & 0x80) usleep(1);
    *(pwm_clk + PWMCLK_CNTL) = 0x5A000006;
    usleep(1);
    *(pwm_clk + PWMCLK_DIV)  = 0x5A000000 | (5 << 12);
    *(pwm_clk + PWMCLK_CNTL) = 0x5A000016;
    usleep(1);
    *(pwm + PWM_RNG1) = 10;
    *(pwm + PWM_DMAC) = (1 << 31) | 0x0707;
    *(pwm + PWM_CTL) = (1 << 5) | (1 << 0);
}

void setup_dma(void) {
    for (int i = 0; i < NUM_BUFFERS; i++) {
        cb[i].ti = (1 << 1) | (1 << 2) | (1 << 5) | (1 << 6);
        cb[i].source_ad = get_physical_address(input_buffer[i]);
        cb[i].dest_ad = get_physical_address((volatile void *)&pwm[PWM_FIF1]);
        cb[i].txfr_len = BUFFER_SIZE * sizeof(uint32_t);
        cb[i].stride = 0;
        cb[i].nextconbk = get_physical_address(&cb[(i + 1) % NUM_BUFFERS]);
    }

    *(dma + DMA_CS) = (1 << 31);
    usleep(1);
    *(dma + DMA_CS) = 0x10FF;
    *(dma + DMA_CONBLK_AD) = get_physical_address(&cb[0]);
    *(dma + DMA_CS) = (1 << 0) | (1 << 2) | (255 << 16);
}

void *process_data_thread(void *arg) {
    int thread_id = *(int*)arg;
    int start = (BUFFER_SIZE / 2) * thread_id;
    int end = start + (BUFFER_SIZE / 2);
    uint32x4_t two = vdupq_n_u32(2);
    
    for (int i = start; i < end; i += 4) {
        __builtin_prefetch(&input_buffer[0][i + 64], 0, 1);
        uint32x4_t input = vld1q_u32(&input_buffer[0][i]);
        uint32x4_t output = vmulq_u32(input, two);
        vst1q_u32(&output_buffer[0][i], output);
    }
    
    return NULL;
}

void process_data(void) {
    pthread_t threads[2];
    int thread_ids[2] = {0, 1};
    
    for (int i = 0; i < 2; i++) {
        pthread_create(&threads[i], NULL, process_data_thread, &thread_ids[i]);
    }
    
    for (int i = 0; i < 2; i++) {
        pthread_join(threads[i], NULL);
    }
}

void set_realtime_priority(void) {
    struct sched_param param;
    param.sched_priority = sched_get_priority_max(SCHED_FIFO);
    if (sched_setscheduler(0, SCHED_FIFO, &param) == -1) {
        perror("sched_setscheduler failed");
        exit(1);
    }
}

void set_cpu_affinity(void) {
    cpu_set_t set;
    CPU_ZERO(&set);
    CPU_SET(2, &set);
    CPU_SET(3, &set);
    if (sched_setaffinity(0, sizeof(set), &set) == -1) {
        perror("sched_setaffinity failed");
        exit(1);
    }
}

void signal_handler(int signum) {
    running = 0;
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <duration_in_seconds>\n", argv[0]);
        exit(1);
    }

    int duration = atoi(argv[1]);
    if (duration <= 0) {
        fprintf(stderr, "Duration must be a positive integer.\n");
        exit(1);
    }

    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = signal_handler;
    sigaction(SIGALRM, &sa, NULL);

    set_realtime_priority();
    set_cpu_affinity();

    setup_io();
    setup_pwm();
    setup_dma();

    struct itimerval timer;
    timer.it_value.tv_sec = duration;
    timer.it_value.tv_usec = 0;
    timer.it_interval.tv_sec = 0;
    timer.it_interval.tv_usec = 0;
    setitimer(ITIMER_REAL, &timer, NULL);

    clock_gettime(CLOCK_MONOTONIC, &start_time);

    int current_buffer = 0;
    while (running) {
        while (!(*(dma + DMA_CS) & (1 << 1)) && running) {
            nanosleep(&(struct timespec){0, 100}, NULL);  // Ridotto a 100 ns
        }
        
        if (!running) break;

        process_data();
        memcpy(input_buffer[current_buffer], output_buffer[current_buffer], BUFFER_SIZE * sizeof(uint32_t));

        current_buffer = (current_buffer + 1) % NUM_BUFFERS;
        total_cycles++;
    }

    clock_gettime(CLOCK_MONOTONIC, &end_time);

    double elapsed_time = (end_time.tv_sec - start_time.tv_sec) +
                          (end_time.tv_nsec - start_time.tv_nsec) / 1e9;
    double frequency = total_cycles / elapsed_time;

    printf("Elapsed time: %.6f seconds\n", elapsed_time);
    printf("Total cycles: %llu\n", total_cycles);
    printf("Average frequency: %.2f Hz\n", frequency);

    return 0;
}