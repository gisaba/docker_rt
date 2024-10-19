FROM debian:latest

# Imposta la directory di lavoro all'interno del container
WORKDIR /usr/src/app

RUN apt-get update && apt-get install -y \ 
    python3 \ 
    python3-libgpiod \
    python3-numpy \
    python3-pulp \
    python3-scipy

# Copia lo script Python nella directory di lavoro
COPY gpiod-test.py .

COPY script-gpio.py .

# Comando di default per eseguire lo script Python
CMD ["python3", "gpiod-test.py"]    
#CMD ["python3", "script-gpio.py"]    