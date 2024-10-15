# Usa una base ufficiale di Ubuntu
FROM ubuntu:latest

# Aggiorna il sistema e installa le dipendenze
RUN apt-get update && apt-get install -y \
    build-essential \
    glpk-utils \
    libglpk-dev

# Copia il codice C all'interno del container
COPY consumer.c /usr/src/consumer.c

# Imposta la directory di lavoro
WORKDIR /usr/src

# Compila il programma C
RUN gcc -o consumer consumer.c -lm

# Esegui il programma compilato
CMD ["./consumer"]
