# Usa una base ufficiale di Ubuntu
FROM ubuntu:latest

# Aggiorna il sistema e installa le dipendenze
RUN apt-get update && apt-get install -y \
    build-essential \
    glpk-utils \
    libglpk-dev

# Copia il codice C all'interno del container
COPY script.c /usr/src/linear_prog.c

# Imposta la directory di lavoro
WORKDIR /usr/src

# Compila il programma C
RUN gcc -o linear_prog linear_prog.c -lglpk

# Esegui il programma compilato
CMD ["./linear_prog"]