#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <sched.h>

// Struttura per memorizzare i parametri del PID
typedef struct {
    float kp;  // Costante proporzionale
    float ki;  // Costante integrale
    float kd;  // Costante derivativa
    float prev_error;  // Errore precedente
    float integral;    // Somma dell'errore integrato
} PID_Controller;

void set_realtime_priority() {
    struct sched_param param;
    param.sched_priority = 99;
    if (sched_setscheduler(0, SCHED_FIFO, &param) != 0) {
        perror("Errore: È necessario eseguire il programma con privilegi di root per impostare la priorità real-time.");
    }
}

// Funzione di inizializzazione del PID
void PID_init(PID_Controller *pid, float kp, float ki, float kd) {
    pid->kp = kp;
    pid->ki = ki;
    pid->kd = kd;
    pid->prev_error = 0.0f;
    pid->integral = 0.0f;
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

int main() {
    double tempo_massimo_ms = 10.0;  // Tempo massimo consentito in millisecondi

    PID_Controller pid;
    PID_init(&pid, 1.0f, 0.1f, 0.01f);  // Impostiamo i guadagni (tune questi valori)

    float setpoint = 100.0f;  // Obiettivo, per esempio una temperatura di 100°C
    float measured_value = 0.0f;  // Valore misurato inizialmente
    float control_output = 0.0f;  // Uscita del controllo PID

    // Eseguiamo il controllo per un certo numero di iterazioni
    for (int i = 0; i < 100; i++) {

        set_realtime_priority();

        struct timespec inizio, fine;
        clock_gettime(CLOCK_MONOTONIC, &inizio);  // Inizio cronometro

        // Calcolare l'uscita del PID
        control_output = PID_compute(&pid, setpoint, measured_value);

        // Simulazione di un sistema: supponiamo che il valore misurato risponda all'uscita del PID
        measured_value += control_output;


        clock_gettime(CLOCK_MONOTONIC, &fine);  // Fine cronometro

        double tempo_esecuzione = (fine.tv_sec - inizio.tv_sec) * 1000.0 + 
                              (fine.tv_nsec - inizio.tv_nsec) / 1000000.0;  // Millisecondi

        // Stampa l'errore e la risposta
        printf("Setpoint: %.2f, Measured Value: %.2f, Control Output: %.2f\n", setpoint, measured_value, control_output);

        // Aggiungi un piccolo ritardo per simulare un loop di controllo
        usleep(100000);  // 100 ms
    }

    return 0;
}
