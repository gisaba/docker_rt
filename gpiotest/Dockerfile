FROM debian:latest

# Imposta la directory di lavoro all'interno del container
WORKDIR /usr/src/app

RUN apt-get update && apt-get install -y \
    pip \
    python3 \ 
    python3-libgpiod 

# Copia il file requirements.txt nella directory di lavoro
COPY requirements.txt .

# Installa le dipendenze presenti nel file requirements.txt
RUN pip install --break-system-packages --no-cache-dir -r requirements.txt

# Copia lo script Python nella directory di lavoro
COPY gpiod-test.py .

COPY script-gpio.py .

# Comando di default per eseguire lo script Python
#CMD ["python3", "gpiod-test.py"]    
CMD ["python3", "script-gpio.py"]    