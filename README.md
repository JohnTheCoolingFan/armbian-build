### rpardini's fork of the Armbian build system (currently `armbian-next`)

- this is (built on top of) `armbian-next` effort, scheduled to be merged upstream into Armbian after the 22.02 release.
- **unofficial!** _please_ don't bother Armbian maintainers with questions or issues about this fork or its images.
- x86 and aarch64 UEFI, BIOS, rpi4b, cloud-images for meson64 boards, OnePlus 5 phone via fastboot, etc
- built
  images: [https://github.com/rpardini/armbian-release/releases](https://github.com/rpardini/armbian-release/releases) -
  never report or talk to upstream Armbian about these.
- It is used mainly to support a home Kubernetes cluster, running on mainline.
- Adds support for cloud-init, netplan, and generally behaves more like an Ubuntu Cloud instance or the Ubuntu
  RaspberryPi build.
- **Using a system extensibility system** called _extensions_ which has been upstreamed!!!
- Unsupported. Some (maybe...) useful backports to Armbian itself are cherry-picked from here and sent upstream.
- Experimental. Don't blame me, or anyone.

------------------------------------------------------------------------------------------------------------------------

[Go check out the upstream project](https://github.com/armbian/build)