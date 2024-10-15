#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <glpk.h>  // Libreria per la programmazione lineare
#include <sched.h>
#include <unistd.h>

void set_realtime_priority() {
    struct sched_param param;
    param.sched_priority = 99;
    if (sched_setscheduler(0, SCHED_FIFO, &param) != 0) {
        perror("Errore: È necessario eseguire il programma con privilegi di root per impostare la priorità real-time.");
    }
}


void minimize_linear_function(int num_variables, int num_constraints, 
                              double constraint_coefficients[][num_variables], 
                              double constraint_constants[], 
                              double min_coeff, double max_coeff) {
    // Inizializza l'ambiente GLPK
    glp_term_out(GLP_OFF);
    glp_prob *lp;
    lp = glp_create_prob();
    glp_set_prob_name(lp, "Linear Programming Problem");
    glp_set_obj_dir(lp, GLP_MIN);  // Imposta la direzione dell'ottimizzazione (minimizzazione)

    // Definisci le variabili e imposta i vincoli delle variabili
    glp_add_cols(lp, num_variables);
    for (int i = 0; i < num_variables; i++) {
        glp_set_col_bnds(lp, i + 1, GLP_LO, min_coeff, 0.0);  // Vincolo x >= min_coeff
    }

    // Crea un array di coefficienti casuali per la funzione obiettivo
    double objective_coefficients[num_variables];
    srand(time(NULL));  // Inizializza il seme del generatore di numeri casuali
    for (int i = 0; i < num_variables; i++) {
        objective_coefficients[i] = min_coeff + ((double)rand() / RAND_MAX) * (max_coeff - min_coeff);
        glp_set_obj_coef(lp, i + 1, objective_coefficients[i]);  // Aggiungi i coefficienti
    }

    // Definisci i vincoli
    glp_add_rows(lp, num_constraints);
    for (int i = 0; i < num_constraints; i++) {
        glp_set_row_bnds(lp, i + 1, GLP_UP, 0.0, constraint_constants[i]);  // Vincoli <=
    }

    // Definisci i coefficienti per i vincoli
    int ia[1 + num_constraints * num_variables]; // Indici riga
    int ja[1 + num_constraints * num_variables]; // Indici colonna
    double ar[1 + num_constraints * num_variables]; // Coefficienti dei vincoli

    int k = 1;
    for (int i = 0; i < num_constraints; i++) {
        for (int j = 0; j < num_variables; j++) {
            ia[k] = i + 1;  // Riga
            ja[k] = j + 1;  // Colonna
            ar[k] = constraint_coefficients[i][j];  // Coefficiente
            k++;
        }
    }

    glp_load_matrix(lp, num_constraints * num_variables, ia, ja, ar);

    // Risolvi il problema
    glp_simplex(lp, NULL);

    // Stampa i risultati
    /*
    printf("Valore minimo della funzione obiettivo: %g\n", glp_get_obj_val(lp));
    for (int i = 0; i < num_variables; i++) {
        printf("Variabile x%d = %g\n", i + 1, glp_get_col_prim(lp, i + 1));
    }
    */

    // Libera la memoria
    glp_delete_prob(lp);
}

void funzione_da_testare() {
    // Esempio: Minimizza una funzione con 3 variabili soggetta a:
    // x + y + z <= 30
    // 2x + 3y + z <= 60
    // x, y, z >= 0

    int num_vars = 3;
    int num_constraints = 2;

    double constraint_coeffs[2][3] = {{1, 1, 1}, {2, 3, 1}};
    double constraint_constants[2] = {30, 60};

    minimize_linear_function(num_vars, num_constraints, constraint_coeffs, constraint_constants, 1, 10);
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
    
    double wait = (2-tempo_esecuzione)*1000;
    //printf("wait : %.2f us\n", wait);
    
    usleep(wait);
    
    double time_step = (wait/1000) + tempo_esecuzione;
    //printf("time_step : %.2f ms\n", time_step);
    
    printf("%.i,%.2f,%.2f\n", iterazione,tempo_esecuzione,time_step);

    /*
    printf("Tempo di esecuzione: %.2f ms\n", tempo_esecuzione);
    if (tempo_esecuzione <= tempo_massimo) {
        printf("\033[92mLa funzione è stata eseguita entro il limite di %.2f ms\033[0m\n", tempo_massimo);
    } else {
        printf("\033[91mLa funzione ha superato il limite di %.2f ms\033[0m\n", tempo_massimo);
    }
    */
}

int main() {
    double tempo_massimo_ms = 10.0;  // Tempo massimo consentito in millisecondi
    
    for (int i = 1; i <= 100000; i++) {
        //printf("Iterazione %d\n", i);
        verifica_tempo_esecuzione(funzione_da_testare, tempo_massimo_ms,i);
    }

    return 0;
}