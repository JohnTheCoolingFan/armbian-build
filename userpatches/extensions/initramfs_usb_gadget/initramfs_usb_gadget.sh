# @TODO: use decent var names. early ones were rips from pmOS. (or: just curl/source the deviceinfo from there)
# @TODO: document the usb gadget with example cmdlines for the host, like
# routed: ifconfig usb0 up 172.16.42.2 netmask 255.255.255.0; sysctl net.ipv4.ip_forward=1; iptables -P FORWARD ACCEPT; iptables -A POSTROUTING -t nat -j MASQUERADE -s 172.16.42.0/24
# bridged: brctl addif lan usb0; ip link set usb0 up

pre_customize_image__inject_initramfs_usb_gadget() {
	local script_file_src="${EXTENSION_DIR}/init-premount/usbgadget.sh"
	local script_file_dst="${SDCARD}/etc/initramfs-tools/scripts/init-premount/usbgadget.sh"
	run_host_command_logged cat "${script_file_src}" "|" sed -e "'s|%%BOARD%%|${BOARD}|g'" ">" "${script_file_dst}"
	run_host_command_logged chmod -v +x "${script_file_dst}"

	# Modules to load
	cat <<- EOD >> "${SDCARD}"/etc/initramfs-tools/modules
		g_ffs
		usb_f_acm
		usb_f_rndis
	EOD

	# If using NetworkManager, add a config file to enable the USB gadget ethernet interface
	[[ -d "${SDCARD}/etc/NetworkManager/system-connections" ]] &&
		cat <<- EOD >> "${SDCARD}/etc/NetworkManager/system-connections/USB Gadget Ethernet.nmconnection"
			[connection]
			id=USB Gadget Ethernet
			type=ethernet
			interface-name=usb0

			[ethernet]

			[ipv4]
			method=auto

			[ipv6]
			addr-gen-mode=default
			method=auto
		EOD

	return 0 # shortcircuit above, avoid error
}

user_config__add_avahi_daemon() {
	add_packages_to_image avahi-daemon
}

config_tweaks_post_family_config__use_usb_gadget_serial_as_console() {
	declare -g SERIALCON="ttyGS0" # This is a serial USB gadget that will be setup by the initramfs, after kernel booted, but before switching into rootfs.
}

# this is a hook for the cloud-init extension. which is not even here ($SRC/extensions) yet
# (it sits on rpardini's userpatches/extensions). and that is fine. this function will never be called.
# @TODO: the extension manager should warn us about that to avoid losing your mind when things dont work.
cloud_init_determine_network_config_template__prefer_usb0_static() {
	# Default to using usb0 with a static IP. effectively no networking, but the user can access it via ssh.
	# If user goes all the way, they can set up dnsmasq/iptables etc to forward traffic to the internet.
	# But then it probably is easier to just bridge hosts eth0 and usb0 together and use usb0-dhcp.
	declare -g CLOUD_INIT_NET_CONFIG_FILE="usb0-dhcp-wait" # "usb0-staticip"
	display_alert "c-i network-config" "${CLOUD_INIT_NET_CONFIG_FILE}" "info"
}
