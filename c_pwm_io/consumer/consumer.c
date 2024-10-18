
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <time.h>
#include <stdint.h> // Add this for intptr_t


#include <math.h>
#include <sched.h>



#define BCM2711_PERI_BASE 0xFE000000
#define GPIO_BASE (BCM2711_PERI_BASE + 0x200000)
#define PAGE_SIZE 4096
#define BLOCK_SIZE 4096

#define INP_GPIO(g) *(gpio+((g)/10)) &= ~(7<<(((g)%10)*3))
#define OUT_GPIO(g) *(gpio+((g)/10)) |=  (1<<(((g)%10)*3))
#define GPIO_READ(g) (*(gpio+13)&(1<<g))

#define INPUT_PIN 18  // GPIO pin for input (same as OUTPUT_PIN in producer)
#define OUTPUT_PIN 17 // GPIO pin for output (optional, for debugging)

volatile unsigned int *gpio;

void setup_io() {
    int mem_fd;
    void *gpio_map;

    if ((mem_fd = open("/dev/mem", O_RDWR|O_SYNC) ) < 0) {
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
        printf("mmap error %d\n", (intptr_t)gpio_map); // Changed here
        exit(-1);
    }

    gpio = (volatile unsigned *)gpio_map;
}

void setup_gpio() {
    INP_GPIO(INPUT_PIN);   // Set input pin as input
    INP_GPIO(OUTPUT_PIN);  // Set output pin as input (for debugging)
    OUT_GPIO(OUTPUT_PIN);  // Then set as output
}

void process_signal(unsigned int input) {
    // Process the input signal here
    // For demonstration, we'll just mirror the input to the output
    if (input) {
        *(gpio+7) = 1 << OUTPUT_PIN;  // Set
    } else {
        *(gpio+10) = 1 << OUTPUT_PIN; // Clear
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
    struct timespec start, end;
    long long int elapsed_ns;
    unsigned int sample_count = 0;
    unsigned int last_input = 0;

    while (1) {
        clock_gettime(CLOCK_MONOTONIC, &start);

        // Read input
        unsigned int input = GPIO_READ(INPUT_PIN);

        // Process input if changed
        if (input != last_input) {
            process_signal(input);
            last_input = input;
            sample_count++;
        }

        clock_gettime(CLOCK_MONOTONIC, &end);

        // Calculate elapsed time in nanoseconds
        elapsed_ns = (end.tv_sec - start.tv_sec) * 1000000000LL + (end.tv_nsec - start.tv_nsec);

        // Print stats every second (comment out for actual real-time operation)
        if (sample_count >= 10000) {  // Assuming 10kHz sample rate
            printf("Processed %u samples. Average time per sample: %lld ns\n", 
                   sample_count, elapsed_ns / sample_count);
            sample_count = 0;
        }
    }

    return 0;
}



// ... rest of the code remains the same
