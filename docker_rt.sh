#!/bin/bash

# Valore di default per cpuset-cpus
CPUSET_CPUS="2-3"

# Funzione per il parsing degli argomenti
for arg in "$@"; do
  case $arg in
    --cpuset-cpus=*)
      CPUSET_CPUS="${arg#*=}"
      shift
      ;;
  esac
done

# Controlla se è stata passata l'immagine come argomento
if [ -z "$1" ]; then
  echo "Usage: $0 <docker_image> [additional_docker_run_options]"
  exit 1
fi

# Estrai l'immagine
DOCKER_IMAGE="$1"
shift  # Sposta tutti gli altri argomenti a destra (li passeremo come opzioni aggiuntive)

# Ottieni il CMD o ENTRYPOINT dall'immagine
DOCKER_CMD=$(docker inspect --format='{{json .Config.Cmd}}' "$DOCKER_IMAGE")
DOCKER_ENTRYPOINT=$(docker inspect --format='{{json .Config.Entrypoint}}' "$DOCKER_IMAGE")

# Verifica quale usare tra CMD e ENTRYPOINT
if [ "$DOCKER_ENTRYPOINT" != "null" ]; then
  FINAL_CMD="$DOCKER_ENTRYPOINT"
else
  FINAL_CMD="$DOCKER_CMD"
fi

# Se entrambi sono null, allora restituisci un errore
if [ "$FINAL_CMD" == "null" ] || [ -z "$FINAL_CMD" ]; then
  echo "Errore: l'immagine non ha un CMD o ENTRYPOINT valido."
  exit 1
fi

# Costruisci il comando con chrt -f 99
FINAL_CMD="chrt -f 99 ${FINAL_CMD}"

# Esegui il container Docker con i parametri specificati e il comando finale
docker run --cpuset-cpus="$CPUSET_CPUS" --ulimit rtprio=99 --cap-add=sys_nice --security-opt seccomp=unconfined "$@" "$DOCKER_IMAGE" /bin/sh -c "$FINAL_CMD"