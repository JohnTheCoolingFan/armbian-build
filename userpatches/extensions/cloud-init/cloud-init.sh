# This extension enables cloud-init.
# It sets up in a way that the user-data, meta-data and network-config reside in /boot (CLOUD_INIT_CONFIG_LOCATION)
# it can be used to setup users, passwords, ssh keys, install packages, install and delegate to ansible, etc.
# cloud providers allow setting user-data, but provide network-config and meta-data themselves; here we try

function extension_prepare_config__050_early_add_cloud_image_suffix() {
	# Add to image suffix. This is done in a 050 hook so should run pretty early, compared to other extensions.
	EXTRA_IMAGE_SUFFIXES+=("-cloud") # global array
}

function extension_prepare_config__950_prepare_cloud_init() { # do it very late so others can set their stuff first
	# Config for cloud-init.
	declare -g SKIP_CLOUD_INIT_CONFIG="${SKIP_CLOUD_INIT_CONFIG:-no}"               # if yes, installs but does not configure anything.
	declare -g CLOUD_INIT_USER_DATA_URL="${CLOUD_INIT_USER_DATA_URL:-files}"        # "files" to use config files, or an URL to go straight to it
	declare -g CLOUD_INIT_INSTANCE_ID="${CLOUD_INIT_INSTANCE_ID:-armbian-${BOARD}}" # "files" to use config files, or an URL to go straight to it
	declare -g CLOUD_INIT_CONFIG_LOCATION="${CLOUD_INIT_CONFIG_LOCATION:-/boot}"    # where on the sdcard c-i will look for user-data, network-config, meta-data files

	declare -g CLOUD_INIT_USE_NETPLAN="${CLOUD_INIT_USE_NETPLAN:-yes}" # use netplan.io and the systemd/networkd renderer. Debian Cloud-images pre-bookworm used ifupdown, but no more

	# Default to using e* devices with dhcp, but not wait for them, so user-data needs to be local-only
	# Change to eth0-dhcp-wait to use https:// includes in user-data, or to something else for non-ethernet devices
	declare -g CLOUD_INIT_NET_CONFIG_FILE="${CLOUD_INIT_NET_CONFIG_FILE:-eth0-dhcp}"

	# If using custom userdata, include that to image suffix; sharing these images might leak the userdata source.
	if [[ "${SKIP_CLOUD_INIT_CONFIG}" != "yes" ]]; then
		if [[ "a${CLOUD_INIT_USER_DATA_URL}" != "afiles" ]]; then
			EXTRA_IMAGE_SUFFIXES+=("-custom-userdata") # global array
		fi
	fi
}

# not so early hook
function extension_prepare_config__990_late_finish_cloud_init_config() {
	display_alert "Enabling cloud-init for" "${DISTRIBUTION}" "info"
	declare -g EXTRA_BSP_NAME="${EXTRA_BSP_NAME}-cloud" # Unique bsp name for this extension: more like ubuntu cloud
	declare -g IMAGE_TYPE=cloud-image                   # Not user-built, stable, etc warnings

	# Sanity check: a "cloud desktop" would make absolutely no sense.
	if [[ "${BUILD_DESKTOP}" == "yes" ]]; then
		exit_with_error "Cloud-init does not make sense with a desktop build."
	fi

	declare -a ci_packages_remove=()
	declare -a ci_packages_install=()

	# Always remove NM openvpn stuff, does not belong in a cloud image
	# Always remove resolvconf, we're gonna use systemd-resolved
	# ifenslave does not belong in a cloud-image
	ci_packages_remove+=("network-manager-openvpn" "ifenslave" "resolvconf")

	# stuff cloud-images shouldn't have, but also armbian itself shouldnt have:
	ci_packages_remove+=("rsyslog") # use journald # @todo armbian should keep journald logs on disk

	# these should be part of armbian's defaults
	ci_packages_install+=("zstd")

	if [[ "${CLOUD_INIT_USE_NETPLAN}" == "yes" ]]; then
		display_alert "Using network-manager with netplan" "${EXTENSION} ${DISTRIBUTION}:${RELEASE}" "info"
		ci_packages_remove+=("network-manager")
		ci_packages_install+=("netplan.io")
	else
		display_alert "Using network-manager with ifupdown" "${EXTENSION} ${DISTRIBUTION}:${RELEASE}" "warn"
		ci_packages_install+=("network-manager" "ifupdown")
		ci_packages_remove+=("netplan.io")
	fi

	# Force systemd-resolved, but not on Focal / Jammy / Buster / Bullseye, those have resolved inside the main systemd package
	if [[ "${RELEASE}" != "focal" ]] && [[ "${RELEASE}" != "jammy" ]] && [[ "${RELEASE}" != "buster" ]] && [[ "${RELEASE}" != "bullseye" ]]; then
		display_alert "Forcing systemd-resolved" "${EXTENSION} ${DISTRIBUTION}:${RELEASE}" "info"
		ci_packages_install+=("systemd-resolved")
	fi

	if [[ "${RELEASE}" == "bullseye" ]]; then
		ci_packages_install+=("isc-dhcp-client")
	fi

	ci_packages_install+=("cloud-init" "cloud-initramfs-growroot" "busybox" "eatmydata" "curl" "tree") # 'busybox' helps with growroot working on bookworm
	ci_packages_install+=("lvm2" "systemd-timesyncd" "wpasupplicant")

	if [[ "${RELEASE}" != "trixie" ]]; then # Hack, trixie recently (2023-10-01) lost this package for some reason
		ci_packages_install+=("thin-provisioning-tools")
	fi

	# This means "add to rootfs cache list", not "for this board".
	add_packages_to_rootfs "${ci_packages_install[@]}"
	declare -g EXTRA_ROOTFS_NAME="${EXTRA_ROOTFS_NAME}-cloud" # Unique rootfs name for this extension; goes together with add_packages_to_rootfs

	# Remove the packages we don't want.
	remove_packages "${ci_packages_remove[@]}"
}

function pre_umount_final_image__300_prepare_cloud_init_startup() {
	local CI_TARGET="${MOUNT}"

	# remove any networkd config leftover from armbian build
	rm -f "${CI_TARGET}"/etc/systemd/network/*.network || true

	# cleanup -- cloud-init makes some Armbian stuff actually get in the way
	[[ -f "${CI_TARGET}/boot/armbian_first_run.txt.template" ]] && rm -f "${CI_TARGET}/boot/armbian_first_run.txt.template"
	[[ -f "${CI_TARGET}/root/.not_logged_in_yet" ]] && rm -f "${CI_TARGET}/root/.not_logged_in_yet"

	# if disabled skip configuration
	if [[ "${SKIP_CLOUD_INIT_CONFIG}" == "yes" ]]; then
		display_alert "Cloud-init config" "skipped, use cloud-native metadata" ""
		return 0
	fi

	display_alert "Configuring cloud-init at" "${CLOUD_INIT_CONFIG_LOCATION}"

	cp "${EXTENSION_DIR}"/config/cloud-cfg.yaml "${CI_TARGET}"/etc/cloud/cloud.cfg.d/99-armbian-boot.cfg

	cp "${EXTENSION_DIR}"/config/meta-data.yaml "${CI_TARGET}${CLOUD_INIT_CONFIG_LOCATION}"/meta-data
	echo -e "\n\ninstance-id: ${CLOUD_INIT_INSTANCE_ID}" >> "${CI_TARGET}${CLOUD_INIT_CONFIG_LOCATION}"/meta-data

	cp "${EXTENSION_DIR}"/config/user-data.yaml "${CI_TARGET}${CLOUD_INIT_CONFIG_LOCATION}"/user-data

	# This module has hook points, just like the regular Armbian build system. So extensions can influence other extensions. Neat?
	# In this case, extensions compete to modify CLOUD_INIT_NET_CONFIG_FILE, so the ordering of the hooks is extremely important.
	[[ $(type -t cloud_init_determine_network_config_template) == function ]] && cloud_init_determine_network_config_template # @TODO: should be a hook

	# Hack, some wierd bug with c-i causes "match:" devices to not be brought up.
	# For now just don't write a default network-config, c-i's default/fallback detection will dhcp it anyway (and that works).
	if [[ ${CLOUD_INIT_NET_CONFIG_FILE} == *"eth0-dhcp"* ]]; then
		display_alert "dhcp-variant (${CLOUD_INIT_NET_CONFIG_FILE})" "written as ${CLOUD_INIT_CONFIG_LOCATION}/network-config.sample" "info"
		cp "${EXTENSION_DIR}"/config/network-configs/${CLOUD_INIT_NET_CONFIG_FILE}.yaml "${CI_TARGET}${CLOUD_INIT_CONFIG_LOCATION}"/network-config.sample
	else
		display_alert "Using network-config" "network-configs/${CLOUD_INIT_NET_CONFIG_FILE}.yaml" "info"
		cp "${EXTENSION_DIR}"/config/network-configs/${CLOUD_INIT_NET_CONFIG_FILE}.yaml "${CI_TARGET}${CLOUD_INIT_CONFIG_LOCATION}"/network-config
	fi

	# Second chance; use a hook to overwrite the network-config file.
	[[ $(type -t cloud_init_modify_network_config) == function ]] && cloud_init_modify_network_config # @TODO: should be a hook

	# overwrite default (user-oriented) user-data with direct #include via CLOUD_INIT_USER_DATA_URL (automation oriented)
	if [[ "a${CLOUD_INIT_USER_DATA_URL}" != "afiles" ]]; then
		display_alert "Cloud-init user-data points directly to" "${CLOUD_INIT_USER_DATA_URL}" "wrn"
		echo -e "#include\n${CLOUD_INIT_USER_DATA_URL}" > "${CI_TARGET}${CLOUD_INIT_CONFIG_LOCATION}"/user-data
	fi

	# Configure logging for cloud-init. INFO is too little and DEBUG too much (as always)
	cp "${EXTENSION_DIR}"/config/debug_logging.yaml "${CI_TARGET}"/etc/cloud/cloud.cfg.d/05_logging.cfg

	# seed the /var/lib/cloud/seed/nocloud directory with symlinks to ${CLOUD_INIT_CONFIG_LOCATION}/*-data|config
	# symlinks always there, be dangling or not.
	local seed_dir="${CI_TARGET}"/var/lib/cloud/seed/nocloud
	mkdir -p "${seed_dir}"
	ln -s "${CLOUD_INIT_CONFIG_LOCATION}/network-config" "${seed_dir}"/network-config
	ln -s "${CLOUD_INIT_CONFIG_LOCATION}/user-data" "${seed_dir}"/user-data
	ln -s "${CLOUD_INIT_CONFIG_LOCATION}/meta-data" "${seed_dir}"/meta-data
}

function config_post_debootstrap_tweaks__restore_systemd_resolved() {
	# do away with the resolv.conf leftover in the image.
	# set up systemd-resolved which is the way cloud images generally work
	rm -f "${SDCARD}"/etc/resolv.conf
	ln -s ../run/systemd/resolve/stub-resolv.conf "${SDCARD}"/etc/resolv.conf
}

function config_pre_install_distribution_specific__preserve_pristine_etc_systemd() {
	# Preserve some stuff from systemd that Armbian build will touch. This way we can let armbian do its thing
	# and then just revert back to the preserved state.
	cp -rp "${SDCARD}"/etc/systemd "${SDCARD}"/etc/systemd.orig
}

function pre_customize_image__lockdown_root_and_password_logins() {
	display_alert "Disabling root password and SSH password logins" "cloud ${DISTRIBUTION} ${RELEASE}" "info"
	run_host_command_logged sed -i -e "'s/PermitRootLogin yes/PermitRootLogin without-password/g'" "${SDCARD}"/etc/ssh/sshd_config
	run_host_command_logged sed -i -e "'s/#PasswordAuthentication yes/PasswordAuthentication no/g'" "${SDCARD}"/etc/ssh/sshd_config
	chroot_sdcard passwd -l root
}

function pre_customize_image__restore_preserved_systemd_and_netplan_stuff() {
	# Enable motd, that is disabled in distro-agnostic because will enabled by firstrun.
	# cloud-init has no firstrun, but I want motd, so
	chmod +x "${SDCARD}"/etc/update-motd.d/*

	# Restore some stuff we preserved in config_pre_install_distribution_specific()
	cp -p "${SDCARD}"/etc/systemd.orig/journald.conf "${SDCARD}"/etc/systemd/journald.conf

	# Make sure we've a pristine resolved.conf
	if [[ -f "${SDCARD}"/etc/systemd.orig/resolved.conf ]]; then
		cp -p "${SDCARD}"/etc/systemd.orig/resolved.conf "${SDCARD}"/etc/systemd/resolved.conf
	else
		display_alert "No resolved.conf found in preserved systemd directory" "cloud ${DISTRIBUTION} ${RELEASE}" "wrn"
	fi

	# Remove the preserved dir
	rm -rf "${SDCARD}"/etc/systemd.orig || true

	# Clean netplan config. Cloud-init will create its own.
	rm -f "${SDCARD}"/etc/netplan/armbian-default.yaml

	# If not using netplan, make sure /etc/network/interfaces exists, otherwise c-i will ignore "eni"/ifupdown
	if [[ "${CLOUD_INIT_USE_NETPLAN}" == "no" ]]; then
		#display_alert "enabling" "NetworkManager-wait-online.service" "warn"
		#chroot_sdcard systemctl enable NetworkManager-wait-online.service

		display_alert "Cloud-init configuring" "/etc/network/interfaces" "info"
		cat <<- EOD > "${SDCARD}"/etc/network/interfaces
			# Include files from /etc/network/interfaces.d:
			source-directory /etc/network/interfaces.d

			# Cloud images dynamically generate config extensions for newly
			# attached interfaces. See /etc/udev/rules.d/75-cloud-ifupdown.rules
			# and /etc/network/cloud-ifupdown-helper. Dynamically generated
			# configuration extensions are stored in /run:
			source-directory /run/network/interfaces.d
		EOD
	fi

	# Update Debian's c-i template for apt, due to bullseye security layout change.
	if [[ "${RELEASE}" == "bullseye" ]]; then
		display_alert "Cloud-init sources.list.debian.tmpl" "${DISTRIBUTION} ${RELEASE}" "info"
		wget --quiet --output-document="${SDCARD}/etc/cloud/templates/sources.list.debian.tmpl" "https://raw.githubusercontent.com/canonical/cloud-init/main/templates/sources.list.debian.tmpl" || display_alert "Failed to update c-i apt template for" "${RELEASE}" "err"
	fi
}
