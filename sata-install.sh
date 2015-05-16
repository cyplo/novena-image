#!/bin/bash
if [ -z $1 ]
then
	echo "Usage: $0 [device]"
	echo "E.g. $0 /dev/mmcblk1"
	exit 1
fi

echo "Constructing a disk image on $1"
exec sudo ./novena-image.sh \
	-d $1 \
	-t sata \
	-s jessie \
	-a pulseaudio-novena_1.1-r1_all.deb \
	-a irqbalance-imx_0.56-1ubuntu4-rmk1_armhf.deb \
	-a novena-disable-ssp_1.1-1_armhf.deb \
	-a u-boot-novena_2014.10-novena-r2-rc17_armhf.deb \
	-a linux-image-3.19.0-00270-g3d69696-dbg_3.19-novena-r10_armhf.deb \
	-l "sudo openssh-server ntp ntpdate dosfstools btrfs-tools \
	    novena-eeprom xserver-xorg-video-modesetting task-gnome-desktop \
	    hicolor-icon-theme gnome-icon-theme tango-icon-theme keychain \
	    avahi-daemon avahi-dnsconfd libnss-mdns btrfs-tools \
	    parted debootstrap python build-essential xscreensaver vlc vim \
	    emacs x11-xserver-utils usbutils unzip apt-file xz-utils \
	    subversion make screen tmux read-edid powertop powermgmt-base \
	    pavucontrol p7zip-full paprefs pciutils nmap ntfs-3g \
	    network-manager-vpnc network-manager-pptp network-manager-openvpn \
	    network-manager-iodine mplayer2 imagemagick icedove \
	    iceweasel gtkwave gnupg2 git git-email git-man fuse freecad \
	    enigmail dc curl clang bridge-utils bluez bluez-tools \
	    bluez-hcidump bison bc automake autoconf pidgin alsa-utils verilog \
	    i2c-tools hwinfo android-tools-adb android-tools-fastboot \
	    android-tools-fsutils bash-completion kicad ncurses-dev gdb lzop \
	    gawk bison g++ gcc flex pkg-config valgrind netcat wireshark \
	    kismet aircrack-ng socat network-manager network-manager-gnome"
