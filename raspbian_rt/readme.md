# Raspbian RT Linux 6.6 toolchain
This folder contains everything is needed to build the Linux kernel toolchain with a configuration for Raspberry Pi 4b, enabled to realtime scheduling policy.
To proceed:

1. Build the image (for example with `docker build . -t linux66_rt`) and run:
```
docker run -v ./build:/data --privileged linux66_rt
``` 

This will generate ./build/linux66_rt.tar.gz containing the Linux 6.6 toolchain built for realtime kernel on a specific raspberry configuration (Raspberry Pi 4b as default)

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

