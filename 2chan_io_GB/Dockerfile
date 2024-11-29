# Usa una base ufficiale di Ubuntu
FROM ubuntu:latest

# Aggiorna il sistema e installa le dipendenze
RUN apt-get update && apt-get install -y \
    build-essential \
    libglpk-dev

# Copia il codice C all'interno del container
COPY spi_timing_test /usr/src/spi_timing_test

# Imposta la directory di lavoro
WORKDIR /usr/src

# Esegui il programma compilato
CMD ["./spi_timing_test"]