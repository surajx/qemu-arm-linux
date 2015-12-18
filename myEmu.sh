#!/bin/bash

LINUX_VER=linux-4.3.2
BUSYBOX_VER=busybox-1.24.1
PROCESSOR_COUNT=8
LINUX_KERNEL_FAMILY=4.x

function runCheck {
    "$@"
    status=$?
    if [ $status -ne 0 ]; then
        echo "ERROR: $@"
	exit -1
    fi
    return $status
}
echo "This is NOT a silent install, there are passwords to enter and menuconfigs to configure. Refer GitHub Wiki for more details."
echo "Checking availability"
echo "ARM GCC CROSS COMPILER: gcc-arm-linux-gnueabi"
echo "QEMU HARDWARE EMULATOR: qemu"
echo "NCURSES DEV Library: libncurses5-dev"
sudo apt-get install gcc-arm-linux-gnueabi qemu libncurses5-dev
CLEAN=0
if [ "$1" == "clean" ]; then
	CLEAN=1
fi
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabi-
MY_ROOT=`pwd`
MY_DOWNLOADS=$MY_ROOT/downloads/
if [ $CLEAN -ne 0 ]; then
	echo "Deleting Current Compiled Code."
	rm -rf $LINUX_VER/ $BUSYBOX_VER/
fi
mkdir -p $MY_DOWNLOADS
cd $MY_DOWNLOADS
if [ ! -f "$LINUX_VER.tar.xz" ]; then
	echo "$LINUX_VER not found in "$MY_DOWNLOADS". Downloading from kernel.org"
	runCheck wget https://www.kernel.org/pub/linux/kernel/v$LINUX_KERNEL_FAMILY/$LINUX_VER.tar.xz
fi
if [ ! -d "$MY_ROOT/$LINUX_VER/" ]; then
	runCheck tar --xz -xvf $LINUX_VER.tar.xz
	cp -r $LINUX_VER $MY_ROOT
fi
cd $MY_ROOT/$LINUX_VER/
LINUX_SRC=`pwd`
runCheck make versatile_defconfig
runCheck make -j $PROCESSOR_COUNT all
cd $MY_DOWNLOADS
if [ ! -f "$BUSYBOX_VER.tar.bz2" ]; then
        echo "$BUSYBOX_VER not found in "$MY_DOWNLOADS". Downloading from busybox.net"
	runCheck wget http://www.busybox.net/downloads/$BUSYBOX_VER.tar.bz2
fi
if [ ! -d "$MY_ROOT/$BUSYBOX_VER/" ]; then
	runCheck tar xvjf $BUSYBOX_VER.tar.bz2
	cp -r $BUSYBOX_VER $MY_ROOT
fi
cd $MY_ROOT/$BUSYBOX_VER/
BUSYBOX_SRC=`pwd`
runCheck make defconfig
echo "BusyBox menuconfig is about to start, follow the below points for an error free compilations."
echo "Busybox Settings==>Build Options==> Select the option Build BuzyBox binary as a static binary(no shared libs)"
echo "Network Utilities==> Omit the Setup RPC Utilities  -  This is optional, compiling with RPC might fail on some systems."
read -p "Press [Enter] key to start menuconfig..."
runCheck make menuconfig
runCheck make -j $PROCESSOR_COUNT install
cd _install
BUSYBOX_INSTALL=`pwd`
mkdir -p proc/ sys/ dev/ memDriver/ etc/ etc/init.d
cp $MY_ROOT/rcS etc/init.d
cd $MY_ROOT/memDriver/
rm -rf memDriver/
mkdir -p memDriver/
cp src/memory.c memDriver/
cp src/Makefile memDriver/
cd memDriver/
#runCheck make -C $LINUX_SRC M=`pwd` modules
#MEM_DRIVER_KO=`pwd`/memory.ko
cd $BUSYBOX_INSTALL/memDriver/
#cp $MEM_DRIVER_KO .
cd $BUSYBOX_INSTALL
find . | cpio -o --format=newc > $BUSYBOX_SRC/rootfs.img
echo "qemu-system-arm -M versatilepb -m 256M -kernel $LINUX_SRC/arch/arm/boot/zImage -initrd $BUSYBOX_SRC/rootfs.img"
runCheck qemu-system-arm -M versatilepb -m 256M -kernel $LINUX_SRC/arch/arm/boot/zImage -initrd $BUSYBOX_SRC/rootfs.img -append "root=/dev/ram rdinit=/sbin/init"