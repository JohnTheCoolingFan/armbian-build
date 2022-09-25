# Ok so here we write an extra partition to the SD card, if that was written.
# This is convenience only, to limit the size to which growpart/growroot will grow the rootfs.
# It is only done directly on the CARD_DEV device after flashing the img to it.
function extension_prepare_config__prepare_lvmmarker() {
	declare -g LVM_MARKER_START="${LVM_MARKER_START:-24}" # adds a partition of the device that wont allow growpart to grow beyond it
	display_alert "LVM marker configured to ${LVM_MARKER_START}Gb" "${CARD_DEVICE}" "info"
}

post_write_sdcard__create_lvmmarker_partition() {
	local LVM_MARKER_NAME="primary" # for mbr
	if [[ "${IMAGE_PARTITION_TABLE}" == "gpt" ]]; then
		LVM_MARKER_NAME="lvmmarker"
	fi
	display_alert "Creating LVM marker partition from ${LVM_MARKER_START}Gb label '${LVM_MARKER_NAME}'" "${CARD_DEVICE}" "info"
	sync # wait for the flashing to finish
	# Fix the partition table to use all the space available.
	printf "fix\n" | parted ---pretend-input-tty "${CARD_DEVICE}" print || echo "Failed fixing/resizing partition table on ${CARD_DEVICE}"
	# Create the marker partition using all the remaining space.
	parted -s "${CARD_DEVICE}" -- mkpart "${LVM_MARKER_NAME}" ext4 "$((LVM_MARKER_START * 1024))MiB" "100%" || echo "Failed creating lvmmarker partition on ${CARD_DEVICE}"
	sync
	display_alert "Done. Printing the final partition table:" "${CARD_DEVICE}" "info"
	parted -s "${CARD_DEVICE}" -- print
}
