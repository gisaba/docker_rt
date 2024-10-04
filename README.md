# Dockerized python container running on real time scheduler

## REQUIREMENTS

- A Linux distro configured with a realtime scheduler.
- Docker installed.

### INSTALLATION and USAGE

1. Clone this repository.
2. Run `docker compose -f docker-compose_python.yml up docker_realtime_python --remove-orphans`
3. Run `docker compose -f docker-compose_csharp.yml up docker_realtime_csharp --remove-orphans`



## INSTALL A REALTIME KERNEL ON YOUR RASPBERRY PI

Just run:

```bash
curl -sSL https://raw.githubusercontent.com/antoniopicone/docker_rt/main/install_realtime_kernel.sh | sudo sh
```
The script will:

- update debian os
- disable unnecessary services
- disable the gui
- disable power management
- install docker
- download the rt toolchain from latest release on GitHub
- install rt kernel from toolchain
- tune the system for realtime
- enable ethernet over usbc (useful to debug on the go)
- cleanup everything after installation

3. Reboot your device and you are ready to go!

**PLEASE NOTE** that this setup will disable WiFi on your Rasperry device so, if you need to connect to the internet, you will need to connect it via ethernet.

### Building Kernel on your own device
Clone this repo and run
```bash
docker build ./raspbian_rt -t rt_kernel
docker run -v ./build:/data rt_kernel
``` 

## RUNNING CYCLITEST ON YOUR DEVICE

There's a docker image you can build from `./cyclictest` folder:

```bash
cd cyclictest
docker build . -t cyclitest_image
```

Once your cyclitest_image is built, you can run:

```
docker run --rm --privileged cyclitest_image -m -Sp99 -i500 -h200 --duration=2m -q
``` 

## RUN DOCKER CONTAINER ON RT DEDICATED CORES

```bash
# Build a test image, like c_fft
docker build ./c_fft -t fft_c

# Run code with realtime priority 99 and nice 0 on dedicated cores
docker run \
  --cpuset-cpus="2-3" \
  --ulimit rtprio=99 \
  --cap-add=sys_nice \
  --security-opt seccomp=unconfined \
  fft_c chrt -f 99 ./fft_prog
```

