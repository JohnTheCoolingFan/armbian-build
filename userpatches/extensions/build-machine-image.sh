function extension_prepare_config__800_build_machine_image() {
	display_alert "Target image will be a build machine" "${EXTENSION}" "info"

	# Get host dependencies, simulating the target, but with all compilers for all arches.
	declare -g -a host_dependencies=()
	host_release="${RELEASE}" target_arch="all" adaptative_prepare_host_dependencies

	# basic deps needed for building, from basic-deps.sh
	host_dependencies+=("uuid-runtime" dialog psmisc acl curl gnupg "gawk")

	# Add deps so it's cached in rootfs.
	display_alert "Added to package list, for build machine" "${host_dependencies[*]@Q}" "debug"
	add_packages_to_rootfs "${host_dependencies[@]}"
	declare -g EXTRA_ROOTFS_NAME="${EXTRA_ROOTFS_NAME}-buildmachine" # Unique rootfs name for this extension; goes together with add_packages_to_rootfs

	EXTRA_IMAGE_SUFFIXES+=("-buildmachine") # global array; '800' hook is pretty much at the end

	unset host_dependencies # cleanup
	return 0
}
