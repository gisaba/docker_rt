import time as time_module
import os
import numpy as np
from scipy.optimize import linprog
import random
from pulp import *
import gpiod
from time import sleep

def minimize_linear_function(num_variables, constraint_coefficients, constraint_constants, min_coeff=1, max_coeff=10):
    """
    Minimizza una funzione obiettivo lineare con coefficienti casuali, soggetta a vincoli lineari.
    
    :param num_variables: Numero di variabili nella funzione obiettivo
    :param constraint_coefficients: Lista di liste, ogni lista interna rappresenta i coefficienti di un vincolo
    :param constraint_constants: Lista delle costanti dei vincoli (termine noto)
    :param min_coeff: Valore minimo per i coefficienti casuali (default: 1)
    :param max_coeff: Valore massimo per i coefficienti casuali (default: 10)
    :return: Dizionario con i valori ottimali delle variabili, il valore minimo della funzione obiettivo e i coefficienti generati
    """
    # Genera coefficienti casuali per la funzione obiettivo
    objective_coefficients = [random.uniform(min_coeff, max_coeff) for _ in range(num_variables)]
    
    # Crea il problema di minimizzazione
    prob = LpProblem("Linear Programming Problem", LpMinimize)
    
    # Crea le variabili
    variables = [LpVariable(f'x{i}', lowBound=random.randint(min_coeff, max_coeff)) for i in range(num_variables)]
    
    # Definisci la funzione obiettivo
    prob += lpSum([objective_coefficients[i] * variables[i] for i in range(num_variables)])
    
    # Aggiungi i vincoli
    for i, coeffs in enumerate(constraint_coefficients):
        prob += lpSum([coeffs[j] * variables[j] for j in range(num_variables)]) <= constraint_constants[i]
    
    # Risolvi il problema
    prob.solve(PULP_CBC_CMD(msg=False))
    
    # Raccogli i risultati
    results = {
        "status": LpStatus[prob.status],
        "objective_value": value(prob.objective),
        "variables": {var.name: var.varValue for var in prob.variables()},
        "objective_coefficients": objective_coefficients
    }
    
    return results



def set_realtime_priority():
    try:
        os.sched_setscheduler(0, os.SCHED_FIFO, os.sched_param(99))
    except PermissionError:
        print("Errore: È necessario eseguire lo script con privilegi di root per impostare la priorità real-time.")
        return False
    return True

def funzione_da_testare():
    
    # Esempio: Minimizza una funzione con 3 variabili soggetta a:
    # x + y + z <= 30
    # 2x + 3y + z <= 60
    # x, y, z >= 0
    
    num_vars = 3
    constraint_coeffs = [[1, 1, 1], [2, 3, 1]]
    constraint_constants = [30, 60]
    
    result = minimize_linear_function(num_vars, constraint_coeffs, constraint_constants)
    
    
    #print("Coefficienti casuali della funzione obiettivo:", result["objective_coefficients"])
    #print("Stato della soluzione:", result["status"])
    #print("Valore minimo della funzione obiettivo:", result["objective_value"])
    #print("Valori ottimali delle variabili:")
    #for var, value in result["variables"].items():
    #    print(f"  {var} = {value}")


    # Simula un'operazione che richiede tempo
    # time.sleep(0.1)

def verifica_tempo_esecuzione(funzione, tempo_massimo):
    if not set_realtime_priority():
        return

    inizio = time_module.perf_counter()
    funzione()
    fine = time_module.perf_counter()

    t_exec = (fine - inizio) 
    tempo_esecuzione = t_exec * 1000  # Converti in millisecondi

    return t_exec

    #print(f"Tempo di esecuzione: {tempo_esecuzione:.2f} ms")
    #if tempo_esecuzione <= tempo_massimo:
    #    print(f"\033[92mOK: La funzione è stata eseguita entro il limite di {tempo_massimo} ms con {tempo_esecuzione} ms\033[0m")
    #else:
    #    print(f"\033[91mOverRun: La funzione ha superato il limite di {tempo_massimo} ms con {tempo_esecuzione} ms\033[0m")


if __name__ == "__main__":
    tempo_massimo_ms = 10  # Tempo massimo consentito in millisecondi
    
    LED_PIN = 17

    chip = gpiod.Chip('gpiochip4')
    led_line = chip.get_line(LED_PIN)
    led_line.request(consumer="LED", type=gpiod.LINE_REQ_DIR_OUT)

    i = 0
    for i in range(1,100000):
        i+=1
        led_line.set_value(1) # Turn on the LED
        tempo_esecuzione = verifica_tempo_esecuzione(funzione_da_testare, tempo_massimo_ms)*1000
        led_line.set_value(0) # Turn off the LED
        t_idle = (tempo_massimo_ms-tempo_esecuzione)/1000
        if t_idle < 0:
            print(f"iterazione {i}")
            print(f"\033[91mOverRun: La funzione ha superato il limite di {tempo_massimo_ms} ms con {tempo_esecuzione} ms\033[0m")
        else:
            sleep(t_idle)
       # Release the GPIO line and clean up resources on program exit

    led_line.release()

    chip.close()