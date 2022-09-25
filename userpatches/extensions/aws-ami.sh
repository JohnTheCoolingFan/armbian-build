user_config__700_aws_ami_config() {
	EXTRA_IMAGE_SUFFIXES+=("-aws")                   # global array
	declare -g UEFI_GRUB_TERMINAL="serial console" # this will go in grub.d config, so Grub displays on serial and console
	declare -g UEFI_GRUB_DISTRO_NAME="Awsrmbian"   # To signal this is the rescue rootfs/grub
	declare -g EXTRA_ROOTFS_MIB_SIZE=256           # arm64 image requires a bit more space for Grub?
	declare -g SERIALCON="ttyS0"                   # AWS forces this
	declare -g UEFI_ENABLE_BIOS_AMD64="no"         # Disable the BIOS-too aspect of UEFI on amd64, this is just uefi
	declare -g SKIP_QCOW2="yes"                    # Skip QCOW2 creation, even if enabled otherwise
	display_alert "AWS AMI variant" "enabled for ${BOARD} with console at ${SERIALCON}" "info"
}
