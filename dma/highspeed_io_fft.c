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
#include <complex.h>
#include <math.h>

#define BCM2711_PERI_BASE     0xFE000000
#define DMA_BASE              (BCM2711_PERI_BASE + 0x007000)
#define PWM_BASE              (BCM2711_PERI_BASE + 0x20C000)
#define PWM_CLK_BASE          (BCM2711_PERI_BASE + 0x101000)
#define GPIO_BASE             (BCM2711_PERI_BASE + 0x200000)

#define BLOCK_SIZE            4096
#define PWM_CHANNEL           0
#define PWM_FIFO              ((PWM_BASE + 0x18) & 0x00FFFFFF)

#define DMA_CHANNEL           5
#define DMA_CS                (DMA_CHANNEL * 0x100 / 4)
#define DMA_CONBLK_AD         (DMA_CS + 1)
#define DMA_TI                (DMA_CS + 2)
#define DMA_SOURCE_AD         (DMA_CS + 3)
#define DMA_DEST_AD           (DMA_CS + 4)
#define DMA_TXFR_LEN          (DMA_CS + 5)
#define DMA_STRIDE            (DMA_CS + 6)
#define DMA_NEXTCONBK         (DMA_CS + 7)
#define DMA_DEBUG             (DMA_CS + 8)

#define CACHE_LINE_SIZE       64
#define FFT_SIZE              1024
#define NUM_BUFFERS           2
#define PWM_FREQUENCY         10000000     // 10 MHz

#define DEFAULT_TIME_SLOT_NS  50

volatile uint32_t *dma_reg;
volatile uint32_t *pwm_reg;
volatile uint32_t *clk_reg;
volatile uint32_t *gpio_reg;

complex float input_buffer[NUM_BUFFERS][FFT_SIZE] __attribute__((aligned(CACHE_LINE_SIZE)));
complex float output_buffer[NUM_BUFFERS][FFT_SIZE] __attribute__((aligned(CACHE_LINE_SIZE)));

static inline uintptr_t bus_to_phys(void * addr) {
    return ((uintptr_t)addr) & ~0xC0000000;
}

struct DMAControlBlock {
    uint32_t ti;
    uint32_t source_ad;
    uint32_t dest_ad;
    uint32_t txfr_len;
    uint32_t stride;
    uint32_t nextconbk;
    uint32_t reserved[2];
} __attribute__((aligned(32)));

struct DMAControlBlock cb[NUM_BUFFERS] __attribute__((aligned(32)));

volatile sig_atomic_t running = 1;
unsigned long long total_cycles = 0;
unsigned long long total_process_time_ns = 0;
unsigned long long overruns = 0;
struct timespec start_time, end_time;

static void setup_io(void) {
    int mem_fd;
    void *dma_map, *pwm_map, *clk_map, *gpio_map;

    if ((mem_fd = open("/dev/mem", O_RDWR|O_SYNC)) < 0) {
        perror("Can't open /dev/mem");
        exit(1);
    }

    dma_map = mmap(NULL, BLOCK_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, mem_fd, DMA_BASE);
    pwm_map = mmap(NULL, BLOCK_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, mem_fd, PWM_BASE);
    clk_map = mmap(NULL, BLOCK_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, mem_fd, PWM_CLK_BASE);
    gpio_map = mmap(NULL, BLOCK_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, mem_fd, GPIO_BASE);

    close(mem_fd);

    if (dma_map == MAP_FAILED || pwm_map == MAP_FAILED || clk_map == MAP_FAILED || gpio_map == MAP_FAILED) {
        perror("mmap error");
        exit(1);
    }

    dma_reg = (volatile uint32_t *)dma_map;
    pwm_reg = (volatile uint32_t *)pwm_map;
    clk_reg = (volatile uint32_t *)clk_map;
    gpio_reg = (volatile uint32_t *)gpio_map;
}

static void setup_pwm(void) {
    // Stop PWM
    pwm_reg[0] = 0;
    usleep(10);

    // Disable clock generator
    clk_reg[40] = 0x5A000000 | (clk_reg[40] & ~0x10);
    usleep(100);

    // Wait for clock to be !BUSY
    while (clk_reg[41] & 0x80);

    // Configure PWM Clock
    int idiv = 2; // 500MHz / 2 = 250MHz
    clk_reg[41] = 0x5A000000 | (idiv << 12);
    clk_reg[40] = 0x5A000010 | 0x6; // src = PLLD (500MHz)

    // Enable clock generator
    clk_reg[40] = 0x5A000011;

    // Configure PWM
    pwm_reg[0] = 0;
    usleep(10);
    pwm_reg[4] = 0;
    usleep(10);

    int range = 250000000 / PWM_FREQUENCY;
    pwm_reg[4] = range;
    pwm_reg[8] = 0x80000000 | 0x7; // clear FIFO
    usleep(10);

    // Enable PWM
    pwm_reg[0] = 0x00000081; // PWEN1=1, MODE1=1
}

static void setup_dma(void) {
    for (int i = 0; i < NUM_BUFFERS; i++) {
        cb[i].ti = (1 << 26) | (1 << 1);
        cb[i].source_ad = bus_to_phys(&input_buffer[i]);
        cb[i].dest_ad = PWM_FIFO;
        cb[i].txfr_len = FFT_SIZE * sizeof(complex float);
        cb[i].stride = 0;
        cb[i].nextconbk = bus_to_phys(&cb[(i + 1) % NUM_BUFFERS]);
    }

    // Reset DMA channel
    dma_reg[DMA_CS] = (1 << 31);
    usleep(10);
    dma_reg[DMA_CS] = 0;

    // Clear any pending interrupt flags
    dma_reg[DMA_CS] = 0x3F;

    // Initialize DMA channel
    dma_reg[DMA_CONBLK_AD] = bus_to_phys(&cb[0]);
    dma_reg[DMA_CS] = (1 << 0) | (255 << 16); // EN=1, PAN=255
}

static unsigned int bit_reverse(unsigned int x, int log2n) {
    int n = 0;
    for (int i = 0; i < log2n; i++) {
        n <<= 1;
        n |= (x & 1);
        x >>= 1;
    }
    return n;
}

static void fft(complex float *vec, int n, int log2n) {
    // Bit reverse
    for (int i = 0; i < n; i++) {
        int j = bit_reverse(i, log2n);
        if (i < j) {
            complex float temp = vec[i];
            vec[i] = vec[j];
            vec[j] = temp;
        }
    }

    // Cooley-Tukey FFT
    for (int s = 1; s <= log2n; s++) {
        int m = 1 << s;
        int m2 = m >> 1;
        complex float w = 1.0;
        complex float wm = cexpf(-I * M_PI / m2);

        for (int j = 0; j < m2; j++) {
            for (int k = j; k < n; k += m) {
                complex float t = w * vec[k + m2];
                complex float u = vec[k];
                vec[k] = u + t;
                vec[k + m2] = u - t;
            }
            w *= wm;
        }
    }
}

static void process_data(void) {
    // Assumiamo che i dati di input siano già nel buffer come numeri complessi
    // Se i dati sono reali, dovresti convertirli in complessi qui

    // Esegui la FFT
    fft(input_buffer[0], FFT_SIZE, 10);  // 10 è log2(1024)

    // Copia il risultato nel buffer di output
    memcpy(output_buffer[0], input_buffer[0], FFT_SIZE * sizeof(complex float));
}

static void set_realtime_priority(void) {
    struct sched_param param;
    param.sched_priority = sched_get_priority_max(SCHED_FIFO);
    if (sched_setscheduler(0, SCHED_FIFO, &param) == -1) {
        perror("sched_setscheduler failed");
        exit(1);
    }
}

static void set_cpu_affinity(void) {
    cpu_set_t set;
    CPU_ZERO(&set);
    CPU_SET(2, &set);
    CPU_SET(3, &set);
    if (sched_setaffinity(0, sizeof(set), &set) == -1) {
        perror("sched_setaffinity failed");
        exit(1);
    }
}

static void signal_handler(int signum) {
    running = 0;
}

static inline uint64_t timespec_to_ns(struct timespec *ts) {
    return (uint64_t)ts->tv_sec * 1000000000ULL + ts->tv_nsec;
}

static uint64_t measure_execution_time(void (*func)(), uint64_t time_slot_ns) {
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);
    
    func();
    
    clock_gettime(CLOCK_MONOTONIC, &end);
    
    uint64_t duration = timespec_to_ns(&end) - timespec_to_ns(&start);
    
    if (duration > time_slot_ns) {
        overruns++;
    }
    
    return duration;
}

static void process_data_wrapper(void) {
    process_data();
}

int main(int argc, char *argv[]) {
    if (argc < 2 || argc > 3) {
        fprintf(stderr, "Usage: %s <duration_in_seconds> [time_slot_in_ns]\n", argv[0]);
        exit(1);
    }

    int duration = atoi(argv[1]);
    if (duration <= 0) {
        fprintf(stderr, "Duration must be a positive integer.\n");
        exit(1);
    }

    uint64_t time_slot_ns = DEFAULT_TIME_SLOT_NS;
    if (argc == 3) {
        time_slot_ns = atoll(argv[2]);
        if (time_slot_ns <= 0) {
            fprintf(stderr, "Time slot must be a positive integer.\n");
            exit(1);
        }
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
        while (!(dma_reg[DMA_CS] & (1 << 1)) && running) {
            asm volatile("yield");
        }
        
        if (!running) break;

        uint64_t execution_time = measure_execution_time(process_data_wrapper, time_slot_ns);
        total_process_time_ns += execution_time;

        memcpy(input_buffer[current_buffer], output_buffer[current_buffer], FFT_SIZE * sizeof(complex float));

        current_buffer = (current_buffer + 1) % NUM_BUFFERS;
        total_cycles++;
    }

    clock_gettime(CLOCK_MONOTONIC, &end_time);

    // Stop DMA
    dma_reg[DMA_CS] = (1 << 31);

    double elapsed_time = (end_time.tv_sec - start_time.tv_sec) +
                          (end_time.tv_nsec - start_time.tv_nsec) / 1e9;
    double frequency = total_cycles / elapsed_time;
    double avg_process_time_ns = (double)total_process_time_ns / total_cycles;

    printf("Elapsed time: %.6f seconds\n", elapsed_time);
    printf("Total cycles: %llu\n", total_cycles);
    printf("Average frequency: %.2f Hz\n", frequency);
    printf("Average process_data execution time: %.2f ns\n", avg_process_time_ns);
    printf("Number of time slot overruns: %llu\n", overruns);
    printf("Percentage of overruns: %.2f%%\n", (double)overruns / total_cycles * 100);

    return 0;
}