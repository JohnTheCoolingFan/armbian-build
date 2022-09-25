# Remove packages that dont belong in a cloud image.
# Wifi, Chrony, etc.
function extension_prepare_config__prepare_mluc() {
	display_alert "Removing uncloudlike packages: vnstat, chrony, etc." "${EXTENSION}" "info"
	# crda is needed for linux-modules-extra which is essential albeit the name
	# crda in turn depends on iw, wireless-regdb
	remove_packages vnstat chrony unattended-upgrades rng-tools networkd-dispatcher hping3 selinux-policy-default dkms
	#remove_packages armbian-config # contains the armbian neofetch. keep it
	# remove most packages from additional: find . -name packages.additional | xargs cat  | sort | uniq | xargs echo
	remove_packages alsa-utils aptitude avahi-autoipd btrfs-progs cracklib-runtime evtest f2fs-tools f3 haveged \
		iputils-arping libcrack2 libdigest-sha-perl \
		libproc-processtable-perl mc ntfs-3g

	# removing all those packages makes the size calculation go too low. compensate.
	if [[ ${EXTRA_ROOTFS_MIB_SIZE} -le 256 ]]; then
		declare -g EXTRA_ROOTFS_MIB_SIZE=256
		display_alert "Setting EXTRA_ROOTFS_MIB_SIZE: ${EXTRA_ROOTFS_MIB_SIZE}" "${EXTENSION}" "info"
	fi

	add_packages_to_rootfs bash-completion ssh-import-id curl dnsutils dosfstools ethtool git jq lsof nano pciutils lm-sensors pv screen unzip wget zsh tmux
	declare -g EXTRA_ROOTFS_NAME="${EXTRA_ROOTFS_NAME}-mluc" # Unique rootfs name for this extension; goes together with add_packages_to_rootfs

	add_packages_to_image systemd-timesyncd # chrony does not play well with systemd / qemu-agent.

	declare -g EXTRA_BSP_NAME="${EXTRA_BSP_NAME}-mluc" # Unique bsp name for this extension: more like ubuntu cloud
}

# Tweak the BSP, removing a bunch of stuff that's great for interactive end-users and memory-deprived systems,
# but not so much for something is is provisioned like a cloud instance.
# @TODO: terrible way, just delete stuff, most stuff will error out at runtime. rethink.
post_family_tweaks_bsp__be_more_like_ubuntu_cloud() {
	#display_alert "Starting files at BSP at ${destination}" "more-like-ubuntu-cloud" "info"
	#find "$destination" -type f

	display_alert "Removing stuff from BSP" "more-like-ubuntu-cloud" "info"
	# Lets obliterate stuff in mass.
	find "$destination" -type f | grep \
		-e "polkit" \
		-e "bootsplash" \
		-e "autologin" \
		-e "firstrun" \
		-e "journald" \
		-e "armbian-config" \
		-e "resize" \
		-e "zram" \
		-e "periodic" \
		-e "interfaces\.default" \
		-e "NetworkManager" \
		-e "profile-sync-daemon" \
		-e "logrotate" \
		-e "ramlog" | xargs rm

	display_alert "Hacking at the BSP" "more-like-ubuntu-cloud" "info"
	# remove a bunch of stuff from bsp so it behaves more like regular ubuntu
	RM_OPTIONS="-f"
	rm ${RM_OPTIONS} "$destination"/etc/apt/apt.conf.d/02-armbian-compress-indexes

	rm ${RM_OPTIONS} "$destination"/etc/cron.d/armbian-truncate-logs
	rm ${RM_OPTIONS} "$destination"/etc/cron.d/armbian-updates
	rm ${RM_OPTIONS} "$destination"/etc/cron.daily/armbian-ram-logging

	rm ${RM_OPTIONS} "$destination"/etc/default/armbian-ramlog.dpkg-dist
	rm ${RM_OPTIONS} "$destination"/etc/default/armbian-zram-config.dpkg-dist

	rm ${RM_OPTIONS} "$destination"/etc/profile.d/armbian-check-first-login.sh

	rm ${RM_OPTIONS} "$destination"/etc/lib/systemd/system/systemd-journald.service.d/override.conf

	rm ${RM_OPTIONS} "$destination"/etc/lib/systemd/system/armbian-firstrun.service
	rm ${RM_OPTIONS} "$destination"/etc/lib/systemd/system/armbian-ramlog.service
	rm ${RM_OPTIONS} "$destination"/etc/lib/systemd/system/armbian-resize-filesystem.service
	rm ${RM_OPTIONS} "$destination"/etc/lib/systemd/system/armbian-zram-config.service

	rm ${RM_OPTIONS} "$destination"/lib/systemd/system/armbian-firstrun-config.service
	rm ${RM_OPTIONS} "$destination"/lib/systemd/system/armbian-firstrun.service
	rm ${RM_OPTIONS} "$destination"/lib/systemd/system/armbian-resize-filesystem.service
	rm ${RM_OPTIONS} "$destination"/lib/systemd/system/armbian-zram-config.service
	rm ${RM_OPTIONS} "$destination"/lib/systemd/system/armbian-disable-autologin.service
	rm ${RM_OPTIONS} "$destination"/lib/systemd/system/armbian-ramlog.service

	#display_alert "Remaining files at BSP at ${destination}" "more-like-ubuntu-cloud" "info"
	#find "$destination" -type f
}
