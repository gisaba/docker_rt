git pull origin main 

docker build -t pid_abcdq_test .

docker run --network=host --cpuset-cpus="2-3" --ulimit rtprio=99 --cap-add=sys_nice --security-opt seccomp=unconfined --privileged --name pid_adc_dq0_test -it --rm --device /dev/gpiochip4:/dev/gpiochip4 pid_abcdq_test
