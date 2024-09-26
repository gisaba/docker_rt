FROM debian:bullseye-slim

# Aggiorna il sistema e installa i pacchetti necessari
RUN apt-get update && \
    apt-get install -y \
    build-essential \
    git \
    libnuma-dev \
    libpopt-dev \
    rt-tests \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Scarica e compila cyclictest se necessario (opzionale, poiché rt-tests include cyclictest)
# RUN git clone https://git.kernel.org/pub/scm/utils/rt-tests/rt-tests.git && \
#     cd rt-tests && \
#     make all && \
#     make install

# Imposta il punto di ingresso per il container
ENTRYPOINT ["cyclictest"]

# Comandi di default (personalizzabili al momento del run)
CMD ["-m", "-Sp90", "-i1000", "-h400", "-q"]

# Note: puoi personalizzare questi parametri di default