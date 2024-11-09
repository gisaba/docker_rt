# Usa una base ufficiale di Ubuntu
FROM ubuntu:latest

# Aggiorna il sistema e installa le dipendenze
RUN apt-get update && apt-get install -y \
    build-essential \
    libglpk-dev 

# Copia il codice C all'interno del container
COPY script.c /usr/src/pid_controller.c

# Imposta la directory di lavoro
WORKDIR /usr/src

# Compila il programma C
RUN gcc -o pid_controller pid_controller.c -lmglpk
#RUN gcc -o pid_controller pid_controller.c -lm


# Esegui il programma compilato
CMD ["./pid_controller"]