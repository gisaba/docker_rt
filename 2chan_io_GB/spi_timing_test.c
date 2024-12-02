#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wiringPi.h>
#include <wiringPiSPI.h>
#include <time.h>
#include <unistd.h>
#include <sched.h>
#include <pthread.h>
#include <errno.h>
#include <sys/mman.h>
#include <limits.h>
#include <sys/types.h>
#include <sys/sysinfo.h>
#include <sys/resource.h>
#include <sys/time.h>
#include <stdint.h>
#include <math.h>

// Configurazione CPU e SPI
#define SPI_CHANNEL_IN    0       // CE0 (GPIO8)  - Canale di lettura
#define SPI_CHANNEL_OUT   1       // CE1 (GPIO7)  - Canale di scrittura
#define SPI_SPEED       1000000   // 2MHz compatibile con Arduino
#define BITS_PER_TRANSFER 8
#define BUFFER_SIZE_BITS 8
#define BUFFER_SIZE_BYTES (BUFFER_SIZE_BITS / 8)
#define TEST_DURATION   100
#define TIMESLOT_NS    100000    // 0.1ms
#define SAMPLE_COUNT   10000
#define READ_CORE      2         // Core dedicato alla lettura
#define PROCESS_CORE   3         // Core dedicato a elaborazione e scrittura
#define USE_REAL_SPI   1
#define LED_PIN 0               // GPIO17 corresponds to wiringPi pin 0

// Struttura per memorizzare i parametri del PID
typedef struct {
    float kp;  // Costante proporzionale
    float ki;  // Costante integrale
    float kd;  // Costante derivativa
    float prev_error;  // Errore precedente
    float integral;    // Somma dell'errore integrato
} PID_Controller;

// Funzione di inizializzazione del PID
void PID_init(PID_Controller *pid, float kp, float ki, float kd) {
    pid->kp = kp;
    pid->ki = ki;
    pid->kd = kd;
    pid->prev_error = 0.0f;
    pid->integral = 0.0f;
}

// Struttura per i buffer SPI con triple buffering e sincronizzazione
typedef struct __attribute__((aligned(64))) {
    union {
        uint64_t value;
        uint8_t bytes[8];
    } read_buffer, write_buffer, process_buffer;
    pthread_mutex_t read_mutex;
    pthread_mutex_t write_mutex;
    pthread_cond_t data_ready;    // Condition variable per sincronizzazione
    int new_data_available;       // Flag per dati disponibili
} spi_buffers_t;

// Struttura per le statistiche temporali
typedef struct __attribute__((aligned(64))) {
    long min_time;
    long max_time;
    long total_time;
    long overruns;
    long iterations;
    long times[SAMPLE_COUNT];
} timing_stats_t;

// Variabili globali
static spi_buffers_t __attribute__((aligned(4096))) spi_buffers = {
    .new_data_available = 0
};

static timing_stats_t read_stats = {
    .min_time = LONG_MAX,
    .max_time = 0,
    .total_time = 0,
    .overruns = 0,
    .iterations = 0
};

static timing_stats_t write_stats = {
    .min_time = LONG_MAX,
    .max_time = 0,
    .total_time = 0,
    .overruns = 0,
    .iterations = 0
};

static volatile int should_stop = 0;

// Aggiungiamo un contatore per il pattern di test
static uint64_t test_counter = 0;

// Funzione per l'inversione dei bit ottimizzata
static inline uint64_t invert_bits(uint64_t value) {
    value = ((value & 0xFFFFFFFF00000000ull) >> 32) | ((value & 0x00000000FFFFFFFFull) << 32);
    value = ((value & 0xFFFF0000FFFF0000ull) >> 16) | ((value & 0x0000FFFF0000FFFFull) << 16);
    value = ((value & 0xFF00FF00FF00FF00ull) >> 8)  | ((value & 0x00FF00FF00FF00FFull) << 8);
    value = ((value & 0xF0F0F0F0F0F0F0F0ull) >> 4)  | ((value & 0x0F0F0F0F0F0F0F0Full) << 4);
    value = ((value & 0xCCCCCCCCCCCCCCCCull) >> 2)  | ((value & 0x3333333333333333ull) << 2);
    value = ((value & 0xAAAAAAAAAAAAAAAAull) >> 1)  | ((value & 0x5555555555555555ull) << 1);
    return value;
}

// Funzione che calcola il valore di controllo PID
float PID_compute(PID_Controller *pid, float setpoint, float measured_value) {
    // Calcolare l'errore
    float error = setpoint - measured_value;

    // Somma dell'errore per la parte integrale
    pid->integral += error;

    // Derivata dell'errore per la parte derivativa
    float derivative = error - pid->prev_error;

    // Calcolare l'uscita PID
    float output = pid->kp * error + pid->ki * pid->integral + pid->kd * derivative;

    // Memorizza l'errore attuale per il prossimo ciclo
    pid->prev_error = error;

    return output;
}

// Funzione di test del controllo PID
void test_PID() {
    PID_Controller pid;
    PID_init(&pid, 1.0f, 0.1f, 0.01f);  // Impostiamo i guadagni (tune questi valori)

    float setpoint = 100.0f;  // Obiettivo, per esempio una temperatura di 100°C
    float measured_value = 0.0f;  // Valore misurato inizialmente
    float control_output = 0.0f;  // Uscita del controllo PID

    // Eseguiamo il controllo per un certo numero di iterazioni
    for (int i = 0; i < 1; i++) {
        // Calcolare l'uscita del PID
        control_output = PID_compute(&pid, setpoint, measured_value);

        // Simulazione di un sistema: supponiamo che il valore misurato risponda all'uscita del PID
        measured_value += control_output;

        // Stampa l'errore e la risposta
        //printf("Setpoint: %.2f, Measured Value: %.2f, Control Output: %.2f\n", setpoint, measured_value, control_output);

        // Aggiungi un piccolo ritardo per simulare un loop di controllo
        usleep(1);  // 5 us
    }
}

// Funzione per il calcolo della differenza temporale
static inline long timespec_diff_ns(struct timespec *start, struct timespec *end) {
    return (end->tv_sec - start->tv_sec) * 1000000000L + 
           (end->tv_nsec - start->tv_nsec);
}

// Funzione per impostare l'affinità del thread su un core specifico
static int set_thread_affinity(int core) {
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(core, &cpuset);
    
    if (pthread_setaffinity_np(pthread_self(), sizeof(cpu_set_t), &cpuset) != 0) {
        perror("pthread_setaffinity_np failed");
        return -1;
    }

    // Verifica l'affinità impostata
    if (pthread_getaffinity_np(pthread_self(), sizeof(cpu_set_t), &cpuset) != 0) {
        perror("Failed to get thread affinity");
        return -1;
    }

    if (!CPU_ISSET(core, &cpuset)) {
        fprintf(stderr, "Failed to set CPU affinity to core %d\n", core);
        return -1;
    }

    printf("Thread in esecuzione su core %d\n", core);
    return 0;
}

// Funzione per la trasformazione ABC a DQ0
void abc_to_dq0(float I_a, float I_b, float I_c, float theta, float *I_d, float *I_q, float *I_0) {
    // Calcolare le componenti della trasformazione
    float cos_theta = cos(theta);
    float sin_theta = sin(theta);

    float cos_theta_minus_2pi_3 = cos(theta - 2 * M_PI / 3);
    float sin_theta_minus_2pi_3 = sin(theta - 2 * M_PI / 3);

    float cos_theta_plus_2pi_3 = cos(theta + 2 * M_PI / 3);
    float sin_theta_plus_2pi_3 = sin(theta + 2 * M_PI / 3);

    // Combinazione della matrice di trasformazione
    *I_d = (2.0 / 3.0) * (cos_theta * I_a + cos_theta_minus_2pi_3 * I_b + cos_theta_plus_2pi_3 * I_c);
    *I_q = (2.0 / 3.0) * (sin_theta * I_a + sin_theta_minus_2pi_3 * I_b + sin_theta_plus_2pi_3 * I_c);
    *I_0 = (1.0 / sqrt(3.0)) * (I_a + I_b + I_c);
}

// Thread di lettura (Core 2)
static void *read_thread(void *arg) {

        
    // Correnti di ingresso nel sistema ABC
    //float I_a = 10.0;  // Corrente A
    //float I_b = 5.0;   // Corrente B
    //float I_c = -3.0;  // Corrente C

    // Correnti di ingresso nel sistema ABC
    float I_a = (double)rand(); // 10.0;  // Corrente A
    float I_b = (double)rand() + 5.0;   // Corrente B
    float I_c = (double)rand() - 3.0;  // Corrente C

    // Angolo di rotazione (ad esempio 30 gradi convertito in radianti)
    float theta = M_PI / 6.0;  // 30° in radianti

    // Variabili per i risultati
    float I_d, I_q, I_0;
    
    struct timespec start, end;
    
    if (set_thread_affinity(READ_CORE) != 0) {
        return NULL;
    }

    struct sched_param param;
    param.sched_priority = sched_get_priority_max(SCHED_FIFO);
    if (sched_setscheduler(0, SCHED_FIFO, &param) != 0) {
        perror("sched_setscheduler failed in read thread");
        return NULL;
    }

    while (!should_stop) {

        clock_gettime(CLOCK_MONOTONIC_RAW, &start);

        pthread_mutex_lock(&spi_buffers.read_mutex);
        
        // Invece di leggere da SPI, generiamo un pattern di test
        #ifdef USE_REAL_SPI

            // Turn the LED on
            digitalWrite(LED_PIN, HIGH);
            
            // Lettura reale SPI (commentata per test)
            if (wiringPiSPIDataRW(SPI_CHANNEL_IN, spi_buffers.read_buffer.bytes, BUFFER_SIZE_BYTES) < 0) {
                perror("SPI read failed");
                pthread_mutex_unlock(&spi_buffers.read_mutex);
                continue;
            }

            // Chiamata alla funzione di trasformazione
            abc_to_dq0(I_a, I_b, I_c, theta, &I_d, &I_q, &I_0);

            test_PID();
        #else
            // Genera pattern di test (scegli uno dei pattern seguenti)
            
            // Opzione 1: Contatore incrementale
            spi_buffers.read_buffer.value = test_counter++;
            
            // Opzione 2: Pattern alternato
            //spi_buffers.read_buffer.value = (test_counter++ % 2) ? 0xAAAAAAAAAAAAAAAA : 0x5555555555555555;
            
            // Opzione 3: Pattern rotante
            //spi_buffers.read_buffer.value = (1ULL << (test_counter++ % 64));
            
            // Simula il tempo di lettura SPI
            usleep(1); // 1 microsecondo di delay
        #endif

        //pthread_mutex_lock(&spi_buffers.write_mutex);
        spi_buffers.new_data_available = 1;
        pthread_cond_signal(&spi_buffers.data_ready);
        //pthread_mutex_unlock(&spi_buffers.write_mutex);

        pthread_mutex_unlock(&spi_buffers.read_mutex);

        clock_gettime(CLOCK_MONOTONIC_RAW, &end);
        
        long elapsed = timespec_diff_ns(&start, &end);
        read_stats.total_time += elapsed;
        read_stats.iterations++;
        if (elapsed < read_stats.min_time) read_stats.min_time = elapsed;
        if (elapsed > read_stats.max_time) read_stats.max_time = elapsed;
        if (elapsed > TIMESLOT_NS) read_stats.overruns++;
        
        // Turn the LED off
        digitalWrite(LED_PIN, LOW);
        usleep((TIMESLOT_NS-elapsed)/ 1000.0);
        
        
        if (read_stats.iterations % 1000 == 0) {
            printf("Read [Core %d] - Test Pattern: 0x%08lX\n", 
                   READ_CORE, spi_buffers.read_buffer.value);
        }
        
    }

    return NULL;
}

// Thread di elaborazione e scrittura (Core 3)
static void *process_write_thread(void *arg) {
    struct timespec start, end;
    
    // Imposta affinità sul core 3
    if (set_thread_affinity(PROCESS_CORE) != 0) {
        return NULL;
    }

    // Imposta priorità real-time
    struct sched_param param;
    param.sched_priority = sched_get_priority_max(SCHED_FIFO);
    if (sched_setscheduler(0, SCHED_FIFO, &param) != 0) {
        perror("sched_setscheduler failed in process/write thread");
        return NULL;
    }

    while (!should_stop) {
        pthread_mutex_lock(&spi_buffers.write_mutex);
        
        // Attesa nuovi dati
        while (!spi_buffers.new_data_available && !should_stop) {
            pthread_cond_wait(&spi_buffers.data_ready, &spi_buffers.write_mutex);
        }
        
        if (should_stop) {
            pthread_mutex_unlock(&spi_buffers.write_mutex);
            break;
        }

        clock_gettime(CLOCK_MONOTONIC_RAW, &start);

        // Elaborazione e scrittura
        spi_buffers.process_buffer.value = spi_buffers.read_buffer.value;
        spi_buffers.write_buffer.value = invert_bits(spi_buffers.process_buffer.value);
        spi_buffers.new_data_available = 0;

        // Scrittura su SPI canale 1
        if (wiringPiSPIDataRW(SPI_CHANNEL_OUT, spi_buffers.write_buffer.bytes, BUFFER_SIZE_BYTES) < 0) {
            perror("SPI write failed");
            pthread_mutex_unlock(&spi_buffers.write_mutex);
            continue;
        }

        pthread_mutex_unlock(&spi_buffers.write_mutex);

        clock_gettime(CLOCK_MONOTONIC_RAW, &end);
        
        // Aggiornamento statistiche
        long elapsed = timespec_diff_ns(&start, &end);
        write_stats.total_time += elapsed;
        write_stats.iterations++;
        if (elapsed < write_stats.min_time) write_stats.min_time = elapsed;
        if (elapsed > write_stats.max_time) write_stats.max_time = elapsed;
        if (elapsed > TIMESLOT_NS) write_stats.overruns++;

        // Output di debug
        if (write_stats.iterations % 1000 == 0) {
            printf("Process/Write [Core %d] - Original: 0x%016lX, Inverted: 0x%016lX\n",
                   PROCESS_CORE, spi_buffers.process_buffer.value, spi_buffers.write_buffer.value);
        }
    }

    return NULL;
}

// Funzione per la stampa delle statistiche
static void print_stats(const char* operation, timing_stats_t *stats) {
    printf("\nStatistiche %s:\n", operation);
    printf("Iterazioni totali: %ld\n", stats->iterations);
    printf("Tempo medio: %.3f µs\n", 
           (double)stats->total_time / stats->iterations / 1000.0);
    printf("Tempo minimo: %.3f µs\n", 
           (double)stats->min_time / 1000.0);
    printf("Tempo massimo: %.3f µs\n", 
           (double)stats->max_time / 1000.0);
    printf("Numero di overrun (>100 µs): %ld (%.2f%%)\n", 
           stats->overruns, 
           (double)stats->overruns * 100.0 / stats->iterations);
    printf("Frequenza media: %.2f kHz\n",
           1000000.0 / ((double)stats->total_time / stats->iterations));
}

int main(void) {
    // Inizializzazione mutex e condition variables
    pthread_mutex_init(&spi_buffers.read_mutex, NULL);
    //pthread_mutex_init(&spi_buffers.write_mutex, NULL);
    pthread_cond_init(&spi_buffers.data_ready, NULL);

    // Impostazione CPU scaling governor
    char cmd[100];
    sprintf(cmd, "echo performance > /sys/devices/system/cpu/cpu%d/cpufreq/scaling_governor", READ_CORE);
    system(cmd);
    sprintf(cmd, "echo performance > /sys/devices/system/cpu/cpu%d/cpufreq/scaling_governor", PROCESS_CORE);
    system(cmd);

    printf("SPI Multi-Core Processing Test (Con Pattern di Test)\n");
    printf("------------------------------------------------\n");
    printf("Configurazione:\n");
    printf("- Modalità: Pattern di Test (Contatore)\n");
    printf("- SPI Speed: %d MHz\n", SPI_SPEED/1000000);
    printf("- Input Channel: %d (CE0)\n", SPI_CHANNEL_IN);
    printf("- Output Channel: %d (CE1)\n", SPI_CHANNEL_OUT);
    printf("- Buffer Size: %d bits (%d bytes)\n", BUFFER_SIZE_BITS, BUFFER_SIZE_BYTES);
    printf("- Read Core: %d\n", READ_CORE);
    printf("- Process/Write Core: %d\n", PROCESS_CORE);
    printf("- Timeslot: %.2f µs\n", TIMESLOT_NS / 1000.0);
    printf("------------------------------------------------\n");

    // Inizializzazione WiringPi e SPI
    if (wiringPiSetup() < 0) {
        fprintf(stderr, "Failed to initialize WiringPi\n");
        return 1;
    }

    // Set the LED_PIN as an output
    pinMode(LED_PIN, OUTPUT);

    if (wiringPiSPISetup(SPI_CHANNEL_IN, SPI_SPEED) < 0) {
        fprintf(stderr, "Failed to initialize SPI input channel\n");
        return 1;
    }

    //if (wiringPiSPISetup(SPI_CHANNEL_OUT, SPI_SPEED) < 0) {
    //    fprintf(stderr, "Failed to initialize SPI output channel\n");
    //   return 1;
    //}

    // Creazione thread
    //pthread_t read_thread_id, process_write_thread_id;
    pthread_t read_thread_id;
    pthread_create(&read_thread_id, NULL, read_thread, NULL);
    //pthread_create(&process_write_thread_id, NULL, process_write_thread, NULL);

    // Attesa per la durata del test
    sleep(TEST_DURATION);

    // Terminazione thread
    should_stop = 1;
    pthread_cond_broadcast(&spi_buffers.data_ready);
    pthread_join(read_thread_id, NULL);
    //pthread_join(process_write_thread_id, NULL);

    // Stampa statistiche finali
    print_stats("Lettura (Core 2)", &read_stats);
    //print_stats("Elaborazione e Scrittura (Core 3)", &write_stats);

    // Cleanup
    pthread_mutex_destroy(&spi_buffers.read_mutex);
    //pthread_mutex_destroy(&spi_buffers.write_mutex);
    pthread_cond_destroy(&spi_buffers.data_ready);

    printf("\nTest completato.\n");
    
    return 0;
}