# Usa un'immagine base di Python 3
FROM python:3.9-slim

# Imposta la directory di lavoro all'interno del container
WORKDIR /usr/src/app

# Copia il file requirements.txt nella directory di lavoro
COPY requirements.txt .

# Installa le dipendenze presenti nel file requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copia lo script Python nella directory di lavoro
COPY script.py .

# Comando di default per eseguire lo script Python
CMD ["python", "./script.py"]