#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <time.h>
#include <math.h>
#include <stdint.h>
#include <sched.h>

#define BCM2711_PERI_BASE 0xFE000000
#define GPIO_BASE (BCM2711_PERI_BASE + 0x200000)
#define PAGE_SIZE 4096
#define BLOCK_SIZE 4096

#define INP_GPIO(g) *(gpio+((g)/10)) &= ~(7<<(((g)%10)*3))
#define OUT_GPIO(g) *(gpio+((g)/10)) |=  (1<<(((g)%10)*3))
#define GPIO_SET *(gpio+7)
#define GPIO_CLR *(gpio+10)

#define OUTPUT_PIN 18

// Signal parameters
#define FUNDAMENTAL_FREQ 50.0
#define SAMPLE_RATE 10000
#define DURATION 1.0

volatile unsigned int *gpio;

void setup_io() {
    int mem_fd;
    void *gpio_map;

    if ((mem_fd = open("/dev/mem", O_RDWR|O_SYNC)) < 0) {
        printf("Can't open /dev/mem\n");
        exit(-1);
    }

    gpio_map = mmap(
        NULL,
        BLOCK_SIZE,
        PROT_READ|PROT_WRITE,
        MAP_SHARED,
        mem_fd,
        GPIO_BASE
    );

    close(mem_fd);

    if (gpio_map == MAP_FAILED) {
        printf("mmap error %ld\n", (intptr_t)gpio_map);
        exit(-1);
    }

    gpio = (volatile unsigned *)gpio_map;
}

void setup_gpio() {
    INP_GPIO(OUTPUT_PIN);
    OUT_GPIO(OUTPUT_PIN);
}

void generate_signal() {
    struct timespec start, now, next;
    clock_gettime(CLOCK_MONOTONIC, &start);
    next = start;

    int samples = (int)(SAMPLE_RATE * DURATION);
    double t, signal;

    for (int i = 0; i < samples; i++) {
        t = (double)i / SAMPLE_RATE;
        
        // Calculate signal with fundamental and three harmonics
        signal = sin(2 * M_PI * FUNDAMENTAL_FREQ * t) +
                 0.3 * sin(2 * M_PI * 2 * FUNDAMENTAL_FREQ * t) +
                 0.1 * sin(2 * M_PI * 3 * FUNDAMENTAL_FREQ * t);

        // Set or clear GPIO based on signal
        if (signal > 0) {
            GPIO_SET = 1 << OUTPUT_PIN;
        } else {
            GPIO_CLR = 1 << OUTPUT_PIN;
        }

        // Precise timing control
        next.tv_nsec += 1000000000 / SAMPLE_RATE;
        if (next.tv_nsec >= 1000000000) {
            next.tv_nsec -= 1000000000;
            next.tv_sec++;
        }
        clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &next, NULL);
        printf("producing");
    }
}


void set_realtime_priority() {
    struct sched_param param;
    param.sched_priority = 99;
    if (sched_setscheduler(0, SCHED_FIFO, &param) != 0) {
        perror("Errore: È necessario eseguire il programma con privilegi di root per impostare la priorità real-time.");
    }
}

int main() {
    setup_io();
    setup_gpio();
    set_realtime_priority();

    // Lock memory to prevent paging
    if (mlockall(MCL_CURRENT | MCL_FUTURE) == -1) {
        perror("mlockall");
	return -2;
    }

    while (1) {
        printf("ciao");
	generate_signal();
    }

    return 0;
}
