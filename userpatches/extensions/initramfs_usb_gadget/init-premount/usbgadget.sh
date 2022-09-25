#!/bin/sh

PREREQ=""
case $1 in
	prereqs)
		echo "$PREREQ"
		exit 0
		;;
esac

deviceinfo_name="Armbian on %%BOARD%%"
deviceinfo_manufacturer="%%BOARD%%"
#usb_idVendor="0x18D1"  # Google Inc.
#usb_idProduct="0xD001" # Nexus 4 (fastboot)
usb_idVendor="0x1d6b" # Linux Foundation
usb_idProduct="0x104" # Ethernet Gadget.
usb_serialnumber="Armbian"

# @TODO: allow to customize this, eg via kernel cmdline (8c:fd:f0 is Qualcomm, seems to result in 'eth1' instead of 'usb0' on the host)
#HOST_ADDRESS="8c:fd:f0:a2:69:42"
#DEV_ADDRESS="8c:fd:f0:a2:69:41"

# @TODO: allow to customize this, eg via kernel cmdline (this seems to result in usb0 on the host)
HOST_ADDRESS="1a:55:89:a2:69:42"
DEV_ADDRESS="1a:55:89:a2:69:41"

clear
echo "Armbian initramfs: start USB Gadget mode."
echo "Armbian initramfs: ttyGS0 and USB Networks."
sleep 1

# Check if there's an USB Device Controller
if [ -z "$(ls /sys/class/udc)" ]; then
	echo "  No USB Device Controller available"
	sleep 5
	return
else
	echo "Armbian initramfs: found UDC: $(ls /sys/class/udc)"
fi

modprobe g_ffs || echo "Armbian initramfs: Failed to modprobe g_ffs"
modprobe usb_f_acm || echo "Armbian initramfs: Failed to modprobe usb_f_acm"
modprobe usb_f_rndis || echo "Armbian initramfs: Failed to modprobe usb_f_rndis"

mkdir -p /config
mount -t configfs -o nodev,noexec,nosuid configfs /config

CONFIGFS=/config/usb_gadget
GADGET=${CONFIGFS}/g1
CONFIG=${GADGET}/configs/c.1
FUNCTIONS=${GADGET}/functions

if ! [ -e "$CONFIGFS" ]; then
	echo "  /config/usb_gadget does not exist, skipping configfs usb gadget"
	sleep 5
	return
fi

echo "  Setting up an USB gadget through configfs"
mkdir ${GADGET} || echo "  Couldn't create ${GADGET}"
echo "$usb_idVendor" > "${GADGET}/idVendor"
echo "$usb_idProduct" > "${GADGET}/idProduct"

# Create english (0x409) strings
mkdir ${GADGET}/strings/0x409 || echo "  Couldn't create ${GADGET}/strings/0x409"

echo "$deviceinfo_manufacturer" > "${GADGET}/strings/0x409/manufacturer"
echo "$usb_serialnumber" > "${GADGET}/strings/0x409/serialnumber"
echo "$deviceinfo_name" > "${GADGET}/strings/0x409/product"

# Create configuration instance
mkdir ${CONFIG} || echo "  Couldn't create ${CONFIG}"

## ACM device

echo "Create ACM device"
mkdir ${FUNCTIONS}/acm.usb0 || echo "  Couldn't create ${FUNCTIONS}/acm.usb0"
ln -s ${FUNCTIONS}/acm.usb0 ${CONFIG} || echo "  Couldn't symlink acm.usb0"

## RNDIS (Network) - Works well with Linux, and supposedly Windows, but not on modern Macs.
echo "Create RNDIS device"
mkdir ${FUNCTIONS}/rndis.usb0 || echo "  Couldn't create ${FUNCTIONS}/rndis.usb0"
echo $HOST_ADDRESS > ${FUNCTIONS}/rndis.usb0/host_addr
echo $DEV_ADDRESS > ${FUNCTIONS}/rndis.usb0/dev_addr
mkdir ${CONFIG}/strings/0x409 || echo "  Couldn't create ${CONFIG}/strings/0x409"
echo "rndis" > ${CONFIG}/strings/0x409/configuration || echo "  Couldn't write configuration name"
ln -s ${FUNCTIONS}/rndis.usb0 ${CONFIG} || echo "  Couldn't symlink rndis.usb0"

## ## ECM (Network) - Should work on Linux and Mac, but not Windows. I actually couldnt make it work under Mac.
## echo "Create ECM device"
## mkdir ${FUNCTIONS}/ecm.usb0 || echo "  Couldn't create ${FUNCTIONS}/ecm.usb0"
## ln -s ${FUNCTIONS}/ecm.usb0 ${CONFIG} || echo "  Couldn't symlink ecm.usb0"

echo "Done creating functions and configs, enabling UDC.."

echo "$(ls /sys/class/udc)" > ${GADGET}/UDC || echo "  Couldn't write UDC"

umount /config

echo "Armbian initramfs: done USB Gadget mode."
sleep 1
