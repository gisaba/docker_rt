obj-m := highspeed_io.o

KDIR := /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

all:
	make -C $(KDIR) M=$(PWD) modules

clean:
	make -C $(KDIR) M=$(PWD) clean

install:
	sudo insmod highspeed_io.ko

remove:
	sudo rmmod highspeed_io

reload: remove install