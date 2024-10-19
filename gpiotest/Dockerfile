FROM debian:latest

RUN apt-get update && apt-get install -y \ 
    python3 \ 
    python3-libgpiod \
    python3-numpy

# Imposta la directory di lavoro all'interno del container
WORKDIR /usr/src/app

# Copia il file requirements.txt nella directory di lavoro
#COPY requirements.txt .

# Installa le dipendenze presenti nel file requirements.txt
#RUN pip install --no-cache-dir -r requirements.txt

# Copia lo script Python nella directory di lavoro
COPY gpiod-test.py .

#COPY "./gpiod-test.py" "/gpiod-test.py"

# Comando di default per eseguire lo script Python
CMD ["python3", "gpiod-test.py"]    