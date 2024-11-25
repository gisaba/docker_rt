git pull origin main 

docker build -t pidtest .

docker run --network=host --cpuset-cpus="2-3" --ulimit rtprio=99 --cap-add=sys_nice --security-opt seccomp=unconfined --privileged --name pid_test -it --rm --device /dev/gpiochip4:/dev/gpiochip4 pidtest
