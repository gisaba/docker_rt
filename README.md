# Dockerized python container running on real time scheduler

## REQUIREMENTS

- A Linux distro configured with a realtime scheduler.
- Docker installed.

## INSTALLATION and USAGE

1. Clone this repository.
2. Run `docker compose -f docker-compose_python.yml up docker_realtime_python --remove-orphans`
3. Run `docker compose -f docker-compose_csharp.yml up docker_realtime_csharp --remove-orphans`


## DEBIAN REALTIME ISO CREATION

You can create a Debian ISO with a pre-confgured realtime kernel and Docker, by running the following commands:

```bash
cd debian_rt
sudo ./image-builder.sh
```