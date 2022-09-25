## Configuration

declare -g ROOTFS_IN_ROOTFS_SIZE_PERCENT=240 # 2.4 times the size of a simple rootfs seems to hit the target. squeeze to your liking.
declare -g ROOTFS_IN_ROOTFS_EXPORT_ONLY="no" # If yes, e2img will not be included, but only copied to output/images/xx.e2img
declare -g DONT_EXPORT_REGULAR_IMG="no"      # If yes, will remove the built .img at the end (used for e2img-only scenarios)

prepare_image_size__rootfs_predict_image_size() {
	# For this to work we need a very big image size. We''ll fill it with itself, so get the size and double it at least.
	# Note: the file is sparse, meaning that is shows larger than it actually is (filled with zeroes).
	# ROOTFS_IN_ROOTFS_SIZE_PERCENT is the magic number, determined empirically.
	declare -g FIXED_IMAGE_SIZE=$((rootfs_size * ROOTFS_IN_ROOTFS_SIZE_PERCENT / 100))
	display_alert "Predicted size of rootfs+rootfs e2img dump to be" "${FIXED_IMAGE_SIZE}Mb" "info"

	if [[ "${ROOTFS_IN_ROOTFS_EXPORT_ONLY}" == "yes" ]]; then
		display_alert "e2image is export only" "NOT increasing to ${FIXED_IMAGE_SIZE}Mb" "info"
		unset FIXED_IMAGE_SIZE
	fi
}

pre_umount_final_image__prepare_rootfs_inside_rootfs() {
	# For sure there is an Armbian env (LOOP_X?) but I didnt figure it out a the time.
	declare -g ROOT_LOOP_DEV_PART
	ROOT_LOOP_DEV_PART=$(mount | grep "${MOUNT}" | grep ext4 | cut -d " " -f 1)
}

# No real need to compress. The file created is sparse, and ext4 works ok with those.
# Also, xz has a ball finding double blocks in the final image.
# Use 800_ prefix to do it quite late in game.
config_post_umount_final_image__800_rootfs_e2img_inside_rootfs() {
	display_alert "Including e2image rootfs-in-rootfs" "Hook Order: ${HOOK_ORDER} of ${HOOK_POINT_TOTAL_FUNCS}" "info"

	# to make sure its unmounted - copied from Armbian codebase, but does not really work.
	while grep -Eq '(${MOUNT}|${DESTIMG})' /proc/mounts; do
		display_alert "Waiting for unmount...." "${MOUNT}" "info"
		sync && sleep 5 && sync
	done

	#make sure it is completely clean...
	display_alert "fsck" "${ROOT_LOOP_DEV_PART}" "info"
	fsck.ext4 -y "${ROOT_LOOP_DEV_PART}" > /dev/null 2>&1
	sync && sleep 5 && sync

	display_alert "e2image dumping" "${ROOT_LOOP_DEV_PART}" "info"
	e2image -rap "${ROOT_LOOP_DEV_PART}" "${MOUNT}/../rootfs.ext4.e2img" > /dev/null 2>&1
	sync && sleep 5 && sync

	local apparent_size actual_size
	apparent_size=$(du -h --apparent-size "${MOUNT}/../rootfs.ext4.e2img" | tr -s "\t" "|" | cut -d "|" -f 1)
	actual_size=$(du -h "${MOUNT}/../rootfs.ext4.e2img" | tr -s "\t" "|" | cut -d "|" -f 1)

	display_alert "e2image sparse dump done" "sizes: apparent: ${apparent_size} actual: ${actual_size} imgsize: ${FIXED_IMAGE_SIZE}Mb" "info"

	if [[ "${ROOTFS_IN_ROOTFS_EXPORT_ONLY}" != "yes" ]]; then
		echo -n "[🐴] Re-mounting..."
		mount "${ROOT_LOOP_DEV_PART}" "${MOUNT}" && sync

		echo -n "Copying..."
		# pipes and sparse files don't mix. be simple about the copy, although it is huge.
		cp "${MOUNT}/../rootfs.ext4.e2img" "${MOUNT}/root/rootfs.ext4.e2img" || {
			echo "" # break a line so error is clearly visible
			display_alert "e2image sparse copy failed" "sizes: apparent: ${apparent_size} actual: ${actual_size} imgsize: ${FIXED_IMAGE_SIZE}" "err"
			display_alert "e2image sparse copy failed" "please increase ROOTFS_IN_ROOTFS_SIZE_PERCENT (currently ${ROOTFS_IN_ROOTFS_SIZE_PERCENT})" "err"
		}
		sync && sleep 5 && sync

		echo -n "Unmount..."
		umount "${MOUNT}" && sync

		echo -n "Clean..."
		rm -f "${MOUNT}"/../rootfs.ext4.e2img
	else
		display_alert "e2image rootfs" "not including in rootfs, for export only" ""
	fi

	echo -n "Sync again..."
	sync

	echo "done."
}

post_build_image__800_export_e2img_rootfs() {
	if [[ "${ROOTFS_IN_ROOTFS_EXPORT_ONLY}" == "yes" ]]; then
		display_alert "Exporting e2img" "${DESTIMG}/${version}.e2img" "info"
		mv "${SRC}"/.tmp/rootfs.ext4.e2img "${DESTIMG}/${version}.e2img" # @TODO: don't use .tmp directly
		sync
	fi
}

post_build_image__860_dont_export_regular_img() {
	if [[ "${DONT_EXPORT_REGULAR_IMG}" == "yes" ]]; then
		display_alert "Cleaning regular .img images" "rootfs-in-rootfs: ${DESTIMG}" "info"
		#ls -laht "${DESTIMG}" "${DESTIMG}/${version}"*
		rm -f "${DESTIMG}/${version}"*.img "${DESTIMG}/${version}"*.img.txt || true
	fi
}
