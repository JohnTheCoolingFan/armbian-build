enable_extension "rootfs_e2img_inside_rootfs" # rootfs in rootfs, will be exported, not really included.

function user_config__700_rescue_uefi_arm64_config() {
	EXTRA_IMAGE_SUFFIXES+=("-rescue") # global array

	declare -g UEFI_GRUB_TERMINAL="serial console"            # this will go in grub.d config, so Grub displays on serial and console
	declare -g CLOUD_INIT_CONFIG_LOCATION="/boot"             # use /boot for cloud-init as well
	unset CLOUD_INIT_USER_DATA_URL                            # for rescue image, don't use the URL, instead cloud-init will default to 'files'
	unset CLOUD_INIT_INSTANCE_ID                              # for rescue image, don't specify the instance-id; cloud-init will default to armbian-BOARD
	declare -g UEFI_GRUB_DISTRO_NAME="ArmbianRescue"          # To signal this is the rescue rootfs/grub
	declare -g ROOTFS_IN_ROOTFS_EXPORT_ONLY="yes"             # If yes, e2img will not be included, but only copied to output/images/xx.e2img
	declare -g DONT_EXPORT_REGULAR_IMG="yes"                  # No use for a non-e2img at the output, it won't ever be used.
	declare -g EXTRA_ROOTFS_MIB_SIZE=256                      # arm64 image requires a bit more space for Grub?
	declare -g SERIALCON="ttyAMA0"                            # These are mostly used in cloud environments, where a console exists.
	[[ "${BOARD}" == *x86* ]] && declare -g SERIALCON="ttyS0" # For Oracle VMs on AMD micro stuff
	declare -g UEFI_ENABLE_BIOS_AMD64="no"                    # Disable the BIOS-too aspect of UEFI on amd64, this is just uefi
	display_alert "Rescue variant" "enabled for ${BOARD} with console at ${SERIALCON}" "info"
}
