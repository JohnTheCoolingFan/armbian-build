# Armbian on the OnePlus 5

## What?

- A 8-core Kryo 280 based ARM64, 4 big cores, 4 small cores.
- 6gb (!!!!) of DDR4 RAM
- 64gb of a decently fast (_"old SSD via USB3"_-like-speeds) ROM
- An USB-C connector, that actually only has a USB2 phy

## Why?!

- I've an old phone lying around. pmOS works well on it. Why not Armbian? It will allow it to join my Kubernetes cluster
  which is all Ubuntu/Armbian based.
- It should work well paired with an Armbian SBC that hosts it via USB, providing power+serial+network.
- The Oneplus 5 will provide sweet 6gb of RAM and some decent Kryo cores in return.
    - Still no idea how it behaves under heavy load. It boots at 29C with 20C ambient, and stays at around 30C with no
      load.
- I don't use cameras, sensors, panels, anything.
- I need mainline for stuff like eBPF and cgroups
- _Maybe_ this can open the way for more fastboot/USB-gadget devices in Armbian in the future

## Mainline efforts

- This is all possible due to JamiKettunen https://github.com/JamiKettunen/linux-mainline-oneplus5 -- thanks!
    - JamiKettunen has had at least the DTB already merged on Torvald's tree. Awesome!
- @TODO: I haven't included any firmware yet, still trying to figure that out. LineageOS has some stuff?

## Linux family: msm8998

- This includes not only the OnePlus 5, but also the OnePlus 5T and some other phones.
- This is of course only tested on the OP5.

## This is not an SBC. It is an Android phone!

- As such, we need to do a _lot_ of stuff differently.
- We use the device's own bootloader chain (which is huge, from Qualcomm CPU bootloader, to XBL UEFI bootloader, to
  `fastboot bootloader`, to kernel +initramfs)
- Resulting build does not include an "image" (.img) file we're used to write to SD and then boot on SBCs...
- Instead we produce a few files that can be flashed via Android standard `fastboot`.
    - `.fastboot.boot.img`
        - Is a "standard" Android `boot.img` that contains
            - The Armbian-built kernel (edge, current), in gzip format
                - The DTB for the board is concatenated at the end
            - The initramfs in gzip format
            - The kernel command-line
            - A bunch of load-addresses for kernel, initrd, etc.
    - `.fastboot.rootfs.img`
        - A somewhat more standard Armbian ARM64 rootfs.
- The device's partition tables should be preserved, otherwise you'll brick the phone.
    - `system` partition (3gb) is `sde26` (!)
    - `userdata` partition (~60gb) is `sde13` (!)
    - `boot` partition, which holds the `boot.img` directly (_not_ `/boot'), is 64mb only
- You can flash the `.fastboot.rootfs.img` to either the `system` or `userdata` partition.
    - But only one of them! If you flash both, behavior is undefined.
    - @TODO: include a `.fastboot.empty.img` so that we can wipe one of these partitions easily.

## There is no serial port or console... until initramfs runs.

- As of the time of writing, the device only supports USB in "peripheral"/"gadget" mode
- So to get any use out of it, you need a host computer (it could be your Linux desktop, or a separate Armbian SBC)
    - To make it accessible/useful, the initramfs sets up the following USB devices:
        - An `ACM` based serial port.
            - It should be `ttyGS0` on the device, and `ttyACM0` on the host computer.
            - It comes up early in the boot process, but is not really usable until boot finishes
            - It should give you a root console after a few minutes.
        - An `RNDIS` based virtual Ethernet port
            - It should be `usb0` both on device and host.
            - By default it is configured on the Device with a static IP address
            - There is an alternative (which?) to use DHCP.
            - It is up to you to configure the host computer to provide network/Internet access to the device:
                - Configure an IP address on the host, and setup routing/forwarding/DNS
                - Simply bridge the `usb0` and say `eth0' on the host, so that the phone gets a "real" network
                  connection
            - I've measured around 200mbit/s one-side throughput over the RNDIS interface.

## Getting started

- I recommend first going through postmarketOS (`pmOS`) instructions for this phone:
  https://wiki.postmarketos.org/wiki/OnePlus_5_(oneplus-cheeseburger)
  pmOS is focused on these phones and their materials help you:
    - Unlock the bootloader (it will wipe your device)
    - Boot into fastboot (Volume Up + Power, but timing/cable/no-cable is important)
    - Flash boot and rootfs into the phone via fastboot
    - Once you go through pmOS process, you'll have learned everything you need, so you'll just flash the `boot.img`
      and `rootfs` produced by this build.

## Work in Progress

- Don't blame me, or anyone, for bricking your phone. ;-)

## Random notes / info

- https://en.wikipedia.org/wiki/Kryo#Kryo_280

