# HOWTO

```
docker build . -t precomp  
docker run -v ./build:/build --privileged -it precomp /bin/bash

```

inside the container, run:

```
sh prepare_image.sh
```

this will mount the raspberry OS image in /raspi-image, inside the container