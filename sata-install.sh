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
	-a u-boot-novena_2014.10-novena-r2-rc17_armhf.deb \
	-a irqbalance-imx_0.56-1ubuntu4-rmk1_armhf.deb \
	-a libdrm-armada2_2.0.2-1_armhf.deb \
	-a libetnaviv_0.0.0-r11_armhf.deb \
	-a novena-usb-hub_1.3-r1_armhf.deb \
	-a linux-headers-novena_3.19-novena-r10_armhf.deb \
	-a linux-image-novena_3.19-novena-r10_armhf.deb \
	-a linux-firmware-image-novena_3.19-novena-r10_armhf.deb \
	-a linux-libc-dev_3.19-novena-r10_armhf.deb \
	-a novena-eeprom_2.3-1_armhf.deb \
	-a kosagi-repo_1.0-r1_all.deb \
	-a novena-firstrun_1.6-r1_all.deb \
	-a xorg-novena_1.5-r1_all.deb \
	-a xserver-xorg-video-armada_0.0.1-r6_armhf.deb \
	-a xserver-xorg-video-armada-etnaviv_0.0.1-r6_armhf.deb \
	-l "sudo openssh-server ntp ntpdate dosfstools btrfs-tools \
	    novena-eeprom xserver-xorg-video-modesetting task-gnome-desktop \
	    hicolor-icon-theme gnome-icon-theme tango-icon-theme keychain \
	    avahi-daemon avahi-dnsconfd libnss-mdns btrfs-tools \
	    parted debootstrap python build-essential xscreensaver vlc vim \
	    x11-xserver-utils usbutils unzip apt-file xz-utils \
	    subversion make screen tmux read-edid powertop powermgmt-base \
	    pavucontrol p7zip-full paprefs pciutils nmap ntfs-3g \
	    network-manager-vpnc network-manager-pptp network-manager-openvpn \
	    network-manager-iodine mplayer2 imagemagick icedove \
	    iceweasel gtkwave gnupg2 git git-email git-man fuse freecad \
	    enigmail dc curl clang bridge-utils bluez bluez-tools \
	    bluez-hcidump bison bc automake autoconf pidgin alsa-utils verilog \
	    i2c-tools hwinfo \
	    bash-completion kicad ncurses-dev gdb lzop \
	    gawk bison g++ gcc flex pkg-config valgrind netcat wireshark \
	    kismet aircrack-ng socat network-manager network-manager-gnome \
            pulseaudio-novena irqbalance-imx novena-disable-ssp \
	    u-boot-novena linux-image-novena" \
	${@:2}

