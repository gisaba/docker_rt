# Dockerized python container running on real time scheduler

## REQUIREMENTS

- A Linux distro configured with a realtime scheduler.
- Docker installed.

### INSTALLATION and USAGE

1. Clone this repository.
2. Run `docker compose -f docker-compose_python.yml up docker_realtime_python --remove-orphans`
3. Run `docker compose -f docker-compose_csharp.yml up docker_realtime_csharp --remove-orphans`



## CREATE A REALTIME KERNEL TOOLCHAIN

You can create and a Linux 6.6 realtime kernel for Raspberry PI board(s) by running the following commands:
 
1. Build the image and run it:
```bash
cd debian_rt
docker build . -t linux66_rt
docker run -v ./build:/data --privileged linux66_rt
``` 

This will generate ./build/linux66_rt.tar.gz containing the Linux 6.6 toolchain built for realtime kernel on a specific raspberry configuration (Raspberry Pi 3 and 4b as default)

2. Copy the generated image `linux66_rt.tar.gz` and the `post_install.sh` file to your target device and, having both files in the same directory, run `sudo post_install.sh` to:

- update debian os
- disable unnecessary services
- disable the gui
- disable power management
- install docker
- install rt kernel from toolchain
- tune the system for realtime
- enable ethernet over usbc (useful to debug on the go)
- cleanup everything after installation

3. Reboot your device and you are ready to go!

**PLEASE NOTE** that this setup will disable WiFi on your Rasperry device so, if you need to connect to the internet, you will need to connect it via ethernet.

## RUNNING CYCLITEST ON YOUR DEVICE

There's a docker image you can build from `./cyclictest` folder:

```bash
cd cyclictest
docker build . -t cyclictest_image
```

Once your cyclitest_image is built, you can run:

```
docker run --rm --privileged cyclitest_image -m -Sp99 -i500 -h200 --duration=2m -q
``` 
