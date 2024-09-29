# Usa una base ufficiale di Ubuntu
FROM ubuntu:latest

# Aggiorna il sistema e installa le dipendenze
RUN apt-get update && apt-get install -y \
    build-essential \
    glpk-utils \
    libfftw3-dev

# Copia il codice C all'interno del container
COPY script.c /usr/src/fft_prog.c

# Imposta la directory di lavoro
WORKDIR /usr/src

# Compila il programma C
RUN gcc -o fft_prog fft_prog.c -lfftw3 -lm

# Esegui il programma compilato
CMD ["./fft_prog"]