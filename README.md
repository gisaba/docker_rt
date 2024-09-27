# Dockerized python container running on real time scheduler

## REQUIREMENTS

- A Linux distro configured with a realtime scheduler.
- Docker installed.

## INSTALLATION and USAGE

1. Clone this repository.
2. Run `docker compose -f docker-compose_python.yml up docker_realtime_python --remove-orphans`
3. Run `docker compose -f docker-compose_csharp.yml up docker_realtime_csharp --remove-orphans`


## DEBIAN REALTIME ISO CREATION

You can create a Debian ISO with a pre-copied realtime kernel by running the following commands:

1. 
```bash
cd debian_rt
docker build . -t precomp  # this will take some time, 15min on M2 CPU
docker run -v ./build:/build --privileged -it precomp /bin/bash

```

2. Inside the container, run:

```
sh prepare_image.sh
```

this generates the Raspberry OS image (Debian 12 slim) in `./debian_rt/build` 

Now you can flash the image with Raspberry PI Imager (feel free to configure your settings and services)

Once you are done, you can 

3. Ssh into Raspberry PI and cd to `/etc/skel/rt`, in this folder you'll find a post_install.sh script that will install the realtime kernel and the necessary packages for the docker.
