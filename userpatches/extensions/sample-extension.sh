# Sample Armbian build system extension with all extension methods.
# This file is auto-generated from and by the build system itself.
# Please, always use the latest version of this file as a starting point for your own extensions.
# Generation date: Mon Nov 22 01:00:22 PM UTC 2021
# Read more about the build system at https://docs.armbian.com/Developer-Guide_Build-Preparation/

#### *give the config a chance to override the family/arch defaults*
###  This hook is called after the family configuration ("sources/families/xxx.conf") is sourced.
###  Since the family can override values from the user configuration and the board configuration,
###  it is often used to in turn override those.
post_family_config__be_more_awesome() {
	# @TODO: Please rename this function to reflect what it does, but preserve the "post_family_config__" prefix.
	display_alert "Being awesome 1!" "${EXTENSION}" "info"
}

#### *Invoke function with user override*
###  Allows for overriding configuration values set anywhere else.
###  It is called after sourcing the "lib.config" file if it exists,
###  but before assembling any package lists.
user_config__be_more_awesome() {
	# @TODO: Please rename this function to reflect what it does, but preserve the "user_config__" prefix.
	display_alert "Being awesome 2!" "${EXTENSION}" "info"
}

#### *allow extensions to prepare their own config, after user config is done*
###  Implementors should preserve variable values pre-set, but can default values an/or validate them.
###  This runs *after* user_config. Don't change anything not coming from other variables or meant to be configured by the user.
extension_prepare_config__be_more_awesome() {
	# @TODO: Please rename this function to reflect what it does, but preserve the "extension_prepare_config__" prefix.
	display_alert "Being awesome 3!" "${EXTENSION}" "info"
}

#### *For final user override, using a function, after all aggregations are done*
###  Called after aggregating all package lists, before the end of "compilation.sh".
###  Packages will still be installed after this is called, so it is the last chance
###  to confirm or change any packages.
post_aggregate_packages__be_more_awesome() {
	# @TODO: Please rename this function to reflect what it does, but preserve the "post_aggregate_packages__" prefix.
	display_alert "Being awesome 4!" "${EXTENSION}" "info"
}

#### *give config a chance modify CTHREADS programatically. A build server may work better with hyperthreads-1 for example.*
###  Called early, before any compilation work starts.
post_determine_cthreads__be_more_awesome() {
	# @TODO: Please rename this function to reflect what it does, but preserve the "post_determine_cthreads__" prefix.
	display_alert "Being awesome 5!" "${EXTENSION}" "info"
}

#### *run before installing host dependencies*
###  you can add packages to install, space separated, to ${EXTRA_BUILD_DEPS} here.
add_host_dependencies__be_more_awesome() {
	# @TODO: Please rename this function to reflect what it does, but preserve the "add_host_dependencies__" prefix.
	display_alert "Being awesome 6!" "${EXTENSION}" "info"
}

#### *fetch host-side sources needed for tools and build*
###  Run early to fetch_from_repo or otherwise obtain sources for needed tools.
fetch_sources_tools__be_more_awesome() {
	# @TODO: Please rename this function to reflect what it does, but preserve the "fetch_sources_tools__" prefix.
	display_alert "Being awesome 7!" "${EXTENSION}" "info"
}

#### *build needed tools for the build, host-side*
###  After sources are fetched, build host-side tools needed for the build.
build_host_tools__be_more_awesome() {
	# @TODO: Please rename this function to reflect what it does, but preserve the "build_host_tools__" prefix.
	display_alert "Being awesome 8!" "${EXTENSION}" "info"
}

#### *family_tweaks_bsp overrrides what is in the config, so give it a chance to override the family tweaks*
###  This should be implemented by the config to tweak the BSP, after the board or family has had the chance to.
post_family_tweaks_bsp__be_more_awesome() {
	# @TODO: Please rename this function to reflect what it does, but preserve the "post_family_tweaks_bsp__" prefix.
	display_alert "Being awesome 9!" "${EXTENSION}" "info"
}

#### *give config a chance to act before install_distribution_specific*
###  Called after "create_rootfs_cache" (_prepare basic rootfs: unpack cache or create from scratch_) but before "install_distribution_specific" (_install distribution and board specific applications_).
pre_install_distribution_specific__be_more_awesome() {
	# @TODO: Please rename this function to reflect what it does, but preserve the "pre_install_distribution_specific__" prefix.
	display_alert "Being awesome 10!" "${EXTENSION}" "info"
}

#### *allow config to do more with the installed kernel/headers*
###  Called after packages, u-boot, kernel and headers installed in the chroot, but before the BSP is installed.
post_install_kernel_debs__be_more_awesome() {
	# @TODO: Please rename this function to reflect what it does, but preserve the "post_install_kernel_debs__" prefix.
	display_alert "Being awesome 11!" "${EXTENSION}" "info"
}

#### *customize the tweaks made by $LINUXFAMILY-specific family_tweaks*
###  It is run after packages are installed in the rootfs, but before enabling additional services.
###  It allows implementors access to the rootfs ("${SDCARD}") in its pristine state after packages are installed.
post_family_tweaks__be_more_awesome() {
	# @TODO: Please rename this function to reflect what it does, but preserve the "post_family_tweaks__" prefix.
	display_alert "Being awesome 12!" "${EXTENSION}" "info"
}

#### *run before customize-image.sh*
###  This hook is called after "customize-image-host.sh" is called, but before the overlay is mounted.
###  It thus can be used for the same purposes as "customize-image-host.sh".
pre_customize_image__be_more_awesome() {
	# @TODO: Please rename this function to reflect what it does, but preserve the "pre_customize_image__" prefix.
	display_alert "Being awesome 13!" "${EXTENSION}" "info"
}

#### *post customize-image.sh hook*
###  Run after the customize-image.sh script is run, and the overlay is unmounted.
post_customize_image__be_more_awesome() {
	# @TODO: Please rename this function to reflect what it does, but preserve the "post_customize_image__" prefix.
	display_alert "Being awesome 14!" "${EXTENSION}" "info"
}

#### *run after removing diversions and qemu with chroot unmounted*
###  Last chance to touch the "${SDCARD}" filesystem before it is copied to the final media.
###  It is too late to run any chrooted commands, since the supporting filesystems are already unmounted.
post_post_debootstrap_tweaks__be_more_awesome() {
	# @TODO: Please rename this function to reflect what it does, but preserve the "post_post_debootstrap_tweaks__" prefix.
	display_alert "Being awesome 15!" "${EXTENSION}" "info"
}

#### *allow custom options for mkfs*
###  Good time to change stuff like mkfs opts, types etc.
pre_prepare_partitions__be_more_awesome() {
	# @TODO: Please rename this function to reflect what it does, but preserve the "pre_prepare_partitions__" prefix.
	display_alert "Being awesome 16!" "${EXTENSION}" "info"
}

#### *allow dynamically determining the size based on the $rootfs_size*
###  Called after "${rootfs_size}" is known, but before "${FIXED_IMAGE_SIZE}" is taken into account.
###  A good spot to determine "FIXED_IMAGE_SIZE" based on "rootfs_size".
###  UEFISIZE can be set to 0 for no UEFI partition, or to a size in MiB to include one.
###  Last chance to set "USE_HOOK_FOR_PARTITION"=yes and then implement create_partition_table hook_point.
prepare_image_size__be_more_awesome() {
	# @TODO: Please rename this function to reflect what it does, but preserve the "prepare_image_size__" prefix.
	display_alert "Being awesome 17!" "${EXTENSION}" "info"
}

#### *if you created your own partitions, this would be a good time to format them*
###  The loop device is mounted, so ${LOOP}p1 is it's first partition etc.
format_partitions__be_more_awesome() {
	# @TODO: Please rename this function to reflect what it does, but preserve the "format_partitions__" prefix.
	display_alert "Being awesome 18!" "${EXTENSION}" "info"
}

#### *allow config to hack into the initramfs create process*
###  Called after rsync has synced both "/root" and "/root" on the target, but before calling "update_initramfs".
pre_update_initramfs__be_more_awesome() {
	# @TODO: Please rename this function to reflect what it does, but preserve the "pre_update_initramfs__" prefix.
	display_alert "Being awesome 19!" "${EXTENSION}" "info"
}

#### *allow config to hack into the image before the unmount*
###  Called before unmounting both "/root" and "/boot".
pre_umount_final_image__be_more_awesome() {
	# @TODO: Please rename this function to reflect what it does, but preserve the "pre_umount_final_image__" prefix.
	display_alert "Being awesome 20!" "${EXTENSION}" "info"
}

#### *allow config to hack into the image after the unmount*
###  Called after unmounting both "/root" and "/boot".
post_umount_final_image__be_more_awesome() {
	# @TODO: Please rename this function to reflect what it does, but preserve the "post_umount_final_image__" prefix.
	display_alert "Being awesome 21!" "${EXTENSION}" "info"
}

#### *custom post build hook*
###  Called after the final .img file is built, before it is (possibly) written to an SD writer.
###  - *NOTE*: this hook used to take an argument ($1) for the final image produced.
###    - Now it is passed as an environment variable "${FINAL_IMAGE_FILE}"
###  It is the last possible chance to modify "$CARD_DEVICE".
post_build_image__be_more_awesome() {
	# @TODO: Please rename this function to reflect what it does, but preserve the "post_build_image__" prefix.
	display_alert "Being awesome 22!" "${EXTENSION}" "info"
}

#### *hook for function to run after build, i.e. to change owner of "$SRC"*
###  Really one of the last hooks ever called. The build has ended. Congratulations.
###  - *NOTE:* this will run only if there were no errors during build process.
run_after_build__be_more_awesome() {
	# @TODO: Please rename this function to reflect what it does, but preserve the "run_after_build__" prefix.
	display_alert "Being awesome 23!" "${EXTENSION}" "info"
}

#### *meta-Meta time!*
###  Implement this hook to work with/on the meta-data made available by the extension manager.
###  Interesting stuff to process:
###  - ""${EXTENSION_MANAGER_TMP_DIR}/hook_point_calls.txt"" contains a list of all hook points called, in order.
###  - For each hook_point in the list, more files will have metadata about that hook point.
###    - "${EXTENSION_MANAGER_TMP_DIR}/hook_point.orig.md" contains the hook documentation at the call site (inline docs), hopefully in Markdown format.
###    - "${EXTENSION_MANAGER_TMP_DIR}/hook_point.compat" contains the compatibility names for the hooks.
###    - "${EXTENSION_MANAGER_TMP_DIR}/hook_point.exports" contains _exported_ environment variables.
###    - "${EXTENSION_MANAGER_TMP_DIR}/hook_point.vars" contains _all_ environment variables.
###  - "${defined_hook_point_functions}" is a map of _all_ the defined hook point functions and their extension information.
###  - "${hook_point_function_trace_sources}" is a map of all the hook point functions _that were really called during the build_ and their BASH_SOURCE information.
###  - "${hook_point_function_trace_lines}" is the same, but BASH_LINENO info.
###  After this hook is done, the "${EXTENSION_MANAGER_TMP_DIR}" will be removed.
extension_metadata_ready__be_more_awesome() {
	# @TODO: Please rename this function to reflect what it does, but preserve the "extension_metadata_ready__" prefix.
	display_alert "Being awesome 24!" "${EXTENSION}" "info"
}
