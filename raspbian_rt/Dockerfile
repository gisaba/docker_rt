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
ARG DEFCONFIG=bcm2711_defconfig
ARG KERNEL
ARG CROSS_COMPILE
ARG ARCH
ARG TARGET


ENV RASPIOS=raspios_lite_arm64
ENV KERNEL=kernel8
ENV ARCH=arm64
ENV DEFCONFIG=$DEFCONFIG
ENV CROSS_COMPILE=aarch64-linux-gnu-
ENV TARGET=arm64

# print the args
RUN echo ${RASPIOS} ${DEFCONFIG} ${KERNEL} ${CROSS_COMPILE} ${ARCH}

RUN make ${DEFCONFIG}
RUN ./scripts/config --enable CONFIG_PREEMPT_RT
RUN ./scripts/config --disable CONFIG_PREEMPT_NONE
RUN ./scripts/config --disable CONFIG_PREEMPT_VOLUNTARY
RUN ./scripts/config --enable CONFIG_PREEMPT
RUN ./scripts/config --enable CONFIG_RCU_PREEMPT
RUN ./scripts/config --enable CONFIG_RCU_BOOST
RUN ./scripts/config --set-val CONFIG_RCU_BOOST_PRIO 99
RUN ./scripts/config --set-val CONFIG_RCU_BOOST_DELAY 0
RUN ./scripts/config --enable CONFIG_HIGH_RES_TIMERS
RUN ./scripts/config --enable CONFIG_NO_HZ_FULL
RUN ./scripts/config --set-val CONFIG_NO_HZ_FULL_ALL n
RUN ./scripts/config --enable CONFIG_CPU_ISOLATION
RUN ./scripts/config --enable CONFIG_RCU_NOCB_CPU
RUN ./scripts/config --enable CONFIG_IRQ_FORCED_THREADING
RUN ./scripts/config --enable CONFIG_SCHED_AUTOGROUP
RUN ./scripts/config --disable CONFIG_FAIR_GROUP_SCHED
RUN ./scripts/config --disable CONFIG_HZ_PERIODIC
RUN ./scripts/config --disable CONFIG_NO_HZ_IDLE
RUN ./scripts/config --set-val CONFIG_HZ 1000
RUN ./scripts/config --disable CONFIG_HOTPLUG_CPU
RUN ./scripts/config --disable CONFIG_DEBUG_KERNEL
RUN ./scripts/config --disable CONFIG_DEBUG_INFO
RUN ./scripts/config --disable CONFIG_DEBUG_FS
RUN ./scripts/config --enable CONFIG_GENERIC_IRQ_EFFECTIVE_AFF_MASK
RUN ./scripts/config --enable CONFIG_RT_GROUP_SCHED

# Abilitazione dei cgroups
RUN ./scripts/config --enable CONFIG_CGROUPS
RUN ./scripts/config --enable CONFIG_CGROUP_DEVICE
RUN ./scripts/config --enable CONFIG_CGROUP_FREEZER
RUN ./scripts/config --enable CONFIG_CGROUP_SCHED
RUN ./scripts/config --enable CONFIG_CPUSETS
RUN ./scripts/config --enable CONFIG_MEMCG
RUN ./scripts/config --enable CONFIG_BLK_CGROUP
RUN ./scripts/config --enable CONFIG_CGROUP_PERF
# Abilitazione delle namespaces
RUN ./scripts/config --enable CONFIG_NAMESPACES
RUN ./scripts/config --enable CONFIG_UTS_NS
RUN ./scripts/config --enable CONFIG_IPC_NS
RUN ./scripts/config --enable CONFIG_PID_NS
RUN ./scripts/config --enable CONFIG_NET_NS
# Supporto per Device Mapper
RUN ./scripts/config --enable CONFIG_BLK_DEV_DM
RUN ./scripts/config --enable CONFIG_DM_THIN_PROVISIONING
# Abilitazione di OverlayFS
RUN ./scripts/config --enable CONFIG_OVERLAY_FS
# Driver di rete necessari
RUN ./scripts/config --enable CONFIG_VETH
RUN ./scripts/config --enable CONFIG_BRIDGE
RUN ./scripts/config --enable CONFIG_NETFILTER_ADVANCED
RUN ./scripts/config --enable CONFIG_NETFILTER_XTABLES
RUN ./scripts/config --enable CONFIG_NETFILTER_XT_TARGET_REDIRECT
RUN ./scripts/config --enable CONFIG_NETFILTER_XT_MATCH_ADDRTYPE
RUN ./scripts/config --enable CONFIG_NETFILTER_XT_MATCH_CONNTRACK
RUN ./scripts/config --enable CONFIG_NF_NAT
RUN ./scripts/config --enable CONFIG_NF_NAT_IPV4
RUN ./scripts/config --enable CONFIG_NF_NAT_IPV6
RUN ./scripts/config --enable CONFIG_IP_NF_FILTER
RUN ./scripts/config --enable CONFIG_IP_NF_TARGET_MASQUERADE


RUN make -j$(nproc) Image.gz modules dtbs
# RUN make INSTALL_MOD_PATH=/raspi-linux-fs modules_install

WORKDIR /rpi-kernel
RUN tar czf linux66_rt_${DEFCONFIG}.tar.gz ./linux
RUN mv linux66_rt_${DEFCONFIG}.tar.gz /tmp/


# Comando da eseguire all'avvio del container
RUN echo "Built kernel"
CMD ["/bin/sh", "-c", "cp /tmp/linux66_rt_${DEFCONFIG}.tar.gz /data/linux66_rt_${DEFCONFIG}.tar.gz"]