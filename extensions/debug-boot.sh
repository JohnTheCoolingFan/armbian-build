# Dumps a lot of info about stuff in /boot

# Add binwalk dependency
function add_host_dependencies__debug_boot_binwalk() {
	display_alert "Adding binwalk dependency" "${EXTENSION} :: ${MOUNT}" "info"
	declare -g EXTRA_BUILD_DEPS="${EXTRA_BUILD_DEPS} binwalk" # @TODO: convert to array later
}

function pre_umount_final_image__debug_boot_dump_slash_boot() {
	display_alert "Dumping /boot contents" "${EXTENSION} :: ${MOUNT}" "info"
	run_host_command_logged tree -C --du -h "${MOUNT}"/boot
	sync

	display_alert "Dumping /boot contents with binwalk" "${EXTENSION} :: ${MOUNT}" "info"
	run_host_command_logged binwalk --term --length=10000 --quiet --log="${MOUNT}"/boot/binwalk.log "${MOUNT}"/boot/*
	sync
	run_host_command_logged cat "${MOUNT}"/boot/binwalk.log
	sync
	run_host_command_logged rm "${MOUNT}"/boot/binwalk.log
	sync

	# Show some common paths
	display_alert "Dumping /boot contents with batcat" "${EXTENSION} :: ${MOUNT}" "info"
	declare -a wanted=("armbianEnv.txt" "boot.cmd" "extlinux/extlinux.conf")
	# loop, and if existing under "${MOUNT}"/boot, show it
	for i in "${wanted[@]}"; do
		if [[ -f "${MOUNT}"/boot/"${i}" ]]; then
			display_alert "Showing ${i}" "${EXTENSION} :: ${MOUNT}" "info"
			run_tool_batcat --file-name "/boot/${i}" "${MOUNT}"/boot/"${i}"
		fi
	done

}
