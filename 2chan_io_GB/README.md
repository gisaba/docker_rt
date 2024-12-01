Compilare con:

gcc -O3 -march=native -mtune=native -ffast-math -o spi_timing_test spi_timing_test.c -lm -lwiringPi -lrt -lpthread

Eseguire con:

sudo taskset -c 2 chrt -f 99 ./spi_timing_test