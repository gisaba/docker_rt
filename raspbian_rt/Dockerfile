FROM debian:12-slim

ENV LINUX_KERNEL_VERSION=6.6
ENV LINUX_KERNEL_BRANCH=stable_20240529
ENV LINUX_KERNEL_RT_PATCH=patch-6.6.30-rt30
ENV RASPIOS_TS=2024-07-04

ENV TZ=Europe/Rome
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update
RUN apt-get install -y git make gcc bison flex libssl-dev bc ncurses-dev kmod \
    crossbuild-essential-arm64 crossbuild-essential-armhf \
    wget zip unzip fdisk nano curl xz-utils jq bash

WORKDIR /rpi-kernel
RUN git clone https://github.com/raspberrypi/linux.git -b ${LINUX_KERNEL_BRANCH} --depth=1
WORKDIR /rpi-kernel/linux
RUN curl https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/${LINUX_KERNEL_VERSION}/older/${LINUX_KERNEL_RT_PATCH}.patch.gz --output ${LINUX_KERNEL_RT_PATCH}.patch.gz && \
    gzip -cd /rpi-kernel/linux/${LINUX_KERNEL_RT_PATCH}.patch.gz | patch -p1 --verbose

ARG RASPIOS
ARG DEFCONFIG
ARG KERNEL
ARG CROSS_COMPILE
ARG ARCH
ARG TARGET


ENV RASPIOS=raspios_lite_arm64
ENV KERNEL=kernel8
ENV ARCH=arm64
ENV DEFCONFIG=bcm2711_defconfig
ENV CROSS_COMPILE=aarch64-linux-gnu-
ENV TARGET=arm64

# print the args
RUN echo ${RASPIOS} ${DEFCONFIG} ${KERNEL} ${CROSS_COMPILE} ${ARCH}

RUN make ${DEFCONFIG}
RUN ./scripts/config --disable CONFIG_VIRTUALIZATION
RUN ./scripts/config --enable CONFIG_PERF_EVENTS
RUN ./scripts/config --enable CONFIG_RTC_CLASS
RUN ./scripts/config --enable CONFIG_PREEMPT_RT
RUN ./scripts/config --disable CONFIG_RCU_EXPERT
RUN ./scripts/config --enable CONFIG_RCU_BOOST
RUN ./scripts/config --set-val CONFIG_RCU_BOOST_DELAY 500
RUN ./scripts/config --enable CONFIG_NO_HZ_FULL
RUN ./scripts/config --enable CONFIG_HZ_1000

RUN make -j6 Image.gz modules dtbs
# RUN make INSTALL_MOD_PATH=/raspi-linux-fs modules_install

WORKDIR /rpi-kernel
RUN tar czf linux66_rt.tar.gz ./linux
RUN mv linux66_rt.tar.gz /tmp/

# Comando da eseguire all'avvio del container
RUN echo "Built kernel"
CMD ["/bin/sh", "-c", "cp /tmp/linux66_rt.tar.gz /data/linux66_rt.tar.gz"]

# RUN wget https://downloads.raspberrypi.com/raspios_lite_armhf/images/raspios_lite_armhf-${RASPIOS_TS}/${RASPIOS_TS}-raspios-bookworm-armhf-lite.img.xz
# RUN xz -d ${RASPIOS_TS}-raspios-bookworm-armhf-lite.img.xz

# # Image offset is calculated by sector size (512 bytes) * start sector of first partition in image (8192), so 512*8192 = 4194304

# RUN apt-get install -y qemu-system-aarch64

# ENV IMAGE_OFFSET=4194304 

# # Start sector of second partition changes according to qemu-img resize!
# ENV LINUX_FS_OFFSET=541065216
# COPY prepare_image.sh . 
# COPY post_install.sh .
