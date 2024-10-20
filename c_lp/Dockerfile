# Usa una base ufficiale di Ubuntu
FROM ubuntu:latest

# Aggiorna il sistema e installa le dipendenze
RUN apt-get update && apt-get install -y \
    build-essential \
    glpk-utils \
    libglpk-dev \
    wiringpi

COPY WiringPi .
#RUN git clone https://github.com/WiringPi/WiringPi.git
#RUN cd WiringPi
RUN bash build
#RUN cd ..

# Copia il codice C all'interno del container
COPY script.c /usr/src/linear_prog.c

# Imposta la directory di lavoro
WORKDIR /usr/src

# Compila il programma C
RUN gcc -o linear_prog linear_prog.c -lglpk -lwiringPi

# Esegui il programma compilato
CMD ["./linear_prog"]