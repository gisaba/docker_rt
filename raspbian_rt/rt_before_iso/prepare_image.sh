#!/bin/bash

qemu-img resize ./${RASPIOS_TS}-raspios-bookworm-armhf-lite.img 2G

# mkdir -p /raspi-image/rt
# mount -o loop,offset=${IMAGE_OFFSET} ./${RASPIOS_TS}-raspios-bookworm-armhf-lite.img /raspi-image/

# mv /rpi-kernel/linux/arch/arm64/boot/Image.gz /raspi-image/rt/Image66_rt.img
# mv /rpi-kernel/linux/arch/arm64/boot/dts/broadcom/*.dtb /raspi-image/rt/
# mv /rpi-kernel/linux/arch/arm64/boot/dts/overlays/*.dtb* /raspi-image/rt/overlays/
# mv /rpi-kernel/linux/arch/arm64/boot/dts/overlays/README /raspi-image/rt/overlays/
#echo "kernel=Image66_rt.img" >> /raspi-image/config.txt
# touch /raspi-image/ssh
# echo 'pi:$6$rBoByrWRKMY1EHFy$ho.LISnfm83CLBWBE/yqJ6Lq1TinRlxw/ImMTPcvvMuUfhQYcMmFnpFXUPowjy2br1NA0IACwF9JKugSNuHoe0' | tee /raspi-image/userconf
# umount /raspi-image


mkdir -p /raspi-linux-fs
mount -o loop,offset=${LINUX_FS_OFFSET} ./${RASPIOS_TS}-raspios-bookworm-armhf-lite.img /raspi-linux-fs/

cd /rpi-kernel/linux

mkdir -p /raspi-linux-fs/etc/skel/rt/boot/dts/overlays
mkdir -p /raspi-linux-fs/etc/skel/rt/boot/dts/broadcom

make INSTALL_MOD_PATH=/raspi-linux-fs/etc/skel/rt modules_install

mv /rpi-kernel/linux/arch/arm64/boot/Image.gz /raspi-linux-fs/etc/skel/rt/boot/Image66_rt.img
mv /rpi-kernel/linux/arch/arm64/boot/dts/broadcom/*.dtb /raspi-linux-fs/etc/skel/rt/boot/dts/broadcom/
mv /rpi-kernel/linux/arch/arm64/boot/dts/overlays/*.dtb* /raspi-linux-fs/etc/skel/rt/boot/dts/overlays/
mv /rpi-kernel/linux/arch/arm64/boot/dts/overlays/README /raspi-linux-fs/etc/skel/rt/boot/dts/overlays/

# Copy post installation tool script
cp post_install.sh /raspi-linux-fs/post_install.sh
# umount /raspi-linux-fs
mv ./${RASPIOS_TS}-raspios-bookworm-armhf-lite.img /build/${RASPIOS_TS}-raspios-bookworm-armhf-lite-rt.img
    