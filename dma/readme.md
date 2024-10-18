

### Design

1. DMA ottimizzato:

Utilizzo di buffer circolari con NUM_BUFFERS (2 in questo caso) per permettere il ping-pong buffering.
Configurazione dei blocchi di controllo DMA per il trasferimento in catena.


2. SIMD (NEON):

Utilizzo di istruzioni NEON nella funzione process_data_thread per elaborare 4 elementi alla volta.


3. Prefetching:

Aggiunto prefetching dei dati nella funzione process_data_thread.


4. Ottimizzazione della cache:

Buffer allineati alla linea di cache (64 byte) e dimensionati per adattarsi bene alla cache L1.


5. Parallelizzazione:

Elaborazione dei dati divisa tra due thread per sfruttare più core.


6. Affinità CPU:

Il processo è vincolato ai core 2 e 3 per ridurre le interruzioni.


7. Riduzione dell'overhead:

Ridotto il tempo di sleep nel loop principale a 100 ns per una reattività maggiore.

### Compiling

To compile, run: 

```bash
gcc -O3 -march=armv8-a+crc -mtune=cortex-a72 -o high_speed_io high_speed_io.c -lrt -lpthread
```


-----------------

raspberrypi-kernel-headers