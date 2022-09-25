post_create_partitions__show_partitions() {
	display_alert "Showing partition table" "${EXTENSION}" "info"
	parted -s "${SDCARD}.raw" -- print || true
	display_alert "Showing partition table sgdisk --print-mbr" "${EXTENSION}" "info"
	sgdisk --print-mbr "${SDCARD}.raw" || true
	display_alert "Showing partition table sgdisk --print (gpt)" "${EXTENSION}" "info"
	sgdisk --print "${SDCARD}.raw" || true
}
