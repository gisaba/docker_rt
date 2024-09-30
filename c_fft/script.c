#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <fftw3.h>
#include <math.h>
#include <time.h>
#include <sched.h>
#include <unistd.h>

#define SAMPLE_RATE 1000  // Frequenza di campionamento in Hz
#define FREQ 50           // Frequenza del segnale sinusoidale in Hz
#define DURATION 2        // Durata del segnale in secondi
#define AMPLITUDE 230.0   // Ampiezza della sinusoide
#define N 2048            // Numero di punti per la FFT

void set_realtime_priority() {
    struct sched_param param;
    param.sched_priority = 99;
    if (sched_setscheduler(0, SCHED_FIFO, &param) != 0) {
        perror("Errore: È necessario eseguire il programma con privilegi di root per impostare la priorità real-time.");
    }
}

void funzione_da_testare() {
    fft_calculation();
}

void verifica_tempo_esecuzione(void (*funzione)(), double tempo_massimo,int iterazione) {
    set_realtime_priority();

    struct timespec inizio, fine;
    clock_gettime(CLOCK_MONOTONIC, &inizio);  // Inizio cronometro

    funzione();

    clock_gettime(CLOCK_MONOTONIC, &fine);  // Fine cronometro

    double tempo_esecuzione = (fine.tv_sec - inizio.tv_sec) * 1000.0 + 
                              (fine.tv_nsec - inizio.tv_nsec) / 1000000.0;  // Millisecondi

    //printf("Tempo di esecuzione: %.2f ms\n", tempo_esecuzione);

    printf("%.i,%.2f,2\n", iterazione,tempo_esecuzione);

    /*
        if (tempo_esecuzione <= tempo_massimo) {
            printf("\033[92mLa funzione è stata eseguita entro il limite di %.2f ms\033[0m\n", tempo_massimo);
        } else {
            printf("\033[91mLa funzione ha superato il limite di %.2f ms\033[0m\n", tempo_massimo);
        }
    */
}

double r2()
{
    return (double)rand() / (double)RAND_MAX ;
}

void fft_calculation() {
    int total_samples = SAMPLE_RATE * DURATION;  // Numero totale di campioni
    float sample_time;                          // Tempo per ogni campione

    /*
    printf("Generazione di un segnale sinusoidale a %d Hz\n", FREQ);
    printf("Frequenza di campionamento: %d Hz\n", SAMPLE_RATE);
    printf("Durata del segnale: %d secondi\n\n", DURATION);
    */

    // Array per i campioni del segnale (input) e per i risultati della FFT (output)
    fftw_complex in[N], out[N];

    for (int n = 0; n < total_samples; n++) {
        sample_time = (float)n / SAMPLE_RATE;                      // Calcolo del tempo per ogni campione
        in[n][0] = AMPLITUDE * r2() * sin(2 * M_PI * FREQ * sample_time); // Genera il valore della sinusoide Parte reale del segnale
        in[n][0] = in[n][0] + AMPLITUDE/10  * r2() * sin(2 * M_PI * FREQ * 2 * sample_time);
        in[n][0] = in[n][0] + AMPLITUDE/100 * r2() * sin(2 * M_PI * FREQ * 3 * sample_time);
        in[n][1] = 0.0;                                            // Parte immaginaria (0 per un segnale reale)
       
       //printf("Campione %d: t = %.4f s, Valore = %.4f\n", n, sample_time, in[n][0]);
    }
    
    // Creare un piano per la trasformata
    fftw_plan plan = fftw_plan_dft_1d(N, in, out, FFTW_FORWARD, FFTW_ESTIMATE);

    // Eseguire la FFT
    fftw_execute(plan);

    // Stampare i risultati della FFT
    /*
    printf("Risultati FFT:\n");
    for (int i = 0; i < N; i++) {
        printf("Freq %d: %f + %fi\n", i, out[i][0], out[i][1]);
    }
    */

    // Pulizia
    fftw_destroy_plan(plan);
    fftw_cleanup();

    return 0;
}

int main() {
    double tempo_massimo_ms = 10.0;  // Tempo massimo consentito in millisecondi

    srand(time(NULL));   // Initialization, should only be called once.

    printf("rownumber,timestep,periodo\n");
    
    for (int i = 1; i <= 100000; i++) {
        //printf("Iterazione %d\n", i);
        verifica_tempo_esecuzione(funzione_da_testare, tempo_massimo_ms,i);
    }

    return 0;
}