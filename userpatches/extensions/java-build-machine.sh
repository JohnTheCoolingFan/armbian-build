function extension_prepare_config__java_build_machine() {
	display_alert "Target image will be a Java build machine" "${EXTENSION}" "info"

	# tmpfs will fill fast, disable
	declare -g FORCE_USE_RAMDISK=no

	# We need extra space in the rootfs for the Java build machine
	display_alert "Adding extra space for Java build machine" "current extra: ${EXTRA_ROOTFS_MIB_SIZE}" "info"
	if [[ ${EXTRA_ROOTFS_MIB_SIZE} -le 1024 ]]; then
		declare -g EXTRA_ROOTFS_MIB_SIZE=1024
		display_alert "GraalVM: Setting new EXTRA_ROOTFS_MIB_SIZE: ${EXTRA_ROOTFS_MIB_SIZE}" "${EXTENSION}" "info"
	fi

	declare -g GRAALVM_ARCH="${ARCH}"
	[[ "${ARCH}" == "arm64" ]] && declare -g GRAALVM_ARCH="aarch64"

	declare -g GRAALVM_VERSION="22.2.0"
	declare -g GRAALVM_FILENAME="graalvm-ce-java17-linux-${GRAALVM_ARCH}-${GRAALVM_VERSION}.tar.gz"

	declare -g GRAALVM_URL="https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-${GRAALVM_VERSION}/${GRAALVM_FILENAME}"
	declare -g GRAALVM_CACHE_DIR="${SRC}/cache/graalvm"
	declare -g GRAALVM_CACHE_FILE="${GRAALVM_CACHE_DIR}/${GRAALVM_FILENAME}"
	declare -g GRAALVM_EXTRACTED_DIR_NAME="graalvm-ce-java17-${GRAALVM_VERSION}"

	display_alert "Adding Java build machine packages" "${EXTENSION}" "info"
	add_packages_to_image openjdk-11-jdk maven zlib1g-dev # This will be default java. zlib1g-dev is needed for graal native builds.
}

function fetch_sources_tools__fetch_graalvm_into_cache() {
	display_alert "Fetching GraalVM tarball" "${EXTENSION}" "info"
	mkdir -p "${GRAALVM_CACHE_DIR}" # Make sure directory exists
	if [[ -f "${GRAALVM_CACHE_FILE}" ]]; then
		display_alert "Using cached GraalVM tarball" "${GRAALVM_CACHE_FILE}" "info"
	else
		display_alert "Fetching GraalVM tarball" "${GRAALVM_URL}" "info"
		run_host_command_logged wget --progress=dot:giga --output-document="${GRAALVM_CACHE_FILE}" "${GRAALVM_URL}"
	fi
}

# Untar and prepare the graalvm JDK into /opt. pre_install_kernel_debs is run a bit earlier than pre_customize_image
function pre_install_kernel_debs__add_graalvm_to_image() {
	# Prepare the native-image stuff. Downloads more stuff.
	#chroot_sdcard ls -la /etc/resolv.conf || true
	#chroot_sdcard cat /etc/resolv.conf || true
	#chroot_sdcard curl "https://www.graalvm.org/component-catalog/v2/graal-updater-component-catalog-java17.properties" || true

	run_host_command_logged mkdir -p "${SDCARD}"/opt
	run_host_command_logged tar -xf "${GRAALVM_CACHE_FILE}" -C "${SDCARD}"/opt
	#chroot_sdcard ls -la /opt/
	chroot_sdcard ln -sv /opt/${GRAALVM_EXTRACTED_DIR_NAME} /opt/graalvm || true

	chroot_sdcard "PATH=/opt/${GRAALVM_EXTRACTED_DIR_NAME}/bin:\${PATH}" "JAVA_HOME=/opt/${GRAALVM_EXTRACTED_DIR_NAME}" gu install native-image # --verbose
}
