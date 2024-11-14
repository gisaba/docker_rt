#include <stdio.h>
#include <math.h>

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

int main() {
    // Correnti di ingresso nel sistema ABC
    float I_a = 10.0;  // Corrente A
    float I_b = 5.0;   // Corrente B
    float I_c = -3.0;  // Corrente C

    // Angolo di rotazione (ad esempio 30 gradi convertito in radianti)
    float theta = M_PI / 6.0;  // 30° in radianti

    // Variabili per i risultati
    float I_d, I_q, I_0;

    // Chiamata alla funzione di trasformazione
    abc_to_dq0(I_a, I_b, I_c, theta, &I_d, &I_q, &I_0);

    // Stampa i risultati
    printf("Componente D (I_d): %.2f\n", I_d);
    printf("Componente Q (I_q): %.2f\n", I_q);
    printf("Componente 0 (I_0): %.2f\n", I_0);

    return 0;
}
