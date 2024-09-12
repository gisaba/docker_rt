# Dockerized python container running on real time scheduler

## REQUIREMENTS

- A Linux distro configured with a realtime scheduler.
- Docker installed.

## INSTALLATION and USAGE

1. Clone this repository.
2. Run `docker compose -f docker-compose_python.yml up docker_realtime_python --remove-orphans`
3. Run `docker compose -f docker-compose_csharp.yml up docker_realtime_csharp --remove-orphans`