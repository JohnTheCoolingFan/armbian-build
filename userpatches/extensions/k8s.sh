#
# SPDX-License-Identifier: GPL-2.0
# Copyright (c) 2024 Ricardo Pardini <ricardo@pardini.net>
# This file is a part of the Armbian Build Framework https://github.com/armbian/build/
#

# Kubernetes (possibly Cluster-API) extension.
# This will deploy the Kuberentes binaries (kubeadm, kubelet, kubectl) from the new official SUSE-OBS repository.
# You can define K8S_MAJOR_MINOR to use a specific major.minor version, but it will always use the latest point release.
# CRI can be provided by k8s-containerd-worker separate project, or you can just use the base distro's containerd, although that is most out of date.
# This extension also tries to trim down the firmware on cloud-metadata images, since by default they include a huge amount of firmware that is not needed.

function extension_prepare_config__k8s() {
	display_alert "Preparing k8s extension" "${EXTENSION}" "info"

	declare -g K8S_MAJOR_MINOR=${K8S_MAJOR_MINOR:-"1.28"}
	EXTRA_IMAGE_SUFFIXES+=("-k8s-${K8S_MAJOR_MINOR}") # global array

	#declare -g EXTRA_BSP_NAME="${EXTRA_BSP_NAME}-k8s" # Unique bsp name for this extension
	#declare -g KEEP_ORIGINAL_OS_RELEASE="yes" # Keep original os-release file when installing bsp and preparing image

	# Disable plymouth stuff (it would be removed at cleanup anyway)
	declare -g PLYMOUTH="no"

	# Disable GRUB menu timeout, we wanna boot fast; for fastest, instead use kernelBoot/kexec, that is already provided by Armbian
	declare -g UEFI_GRUB_TIMEOUT=0

	display_alert "Trimming down firmware" "${EXTENSION} ${K8S_MAJOR_MINOR}" "info"
	declare -g INSTALL_ARMBIAN_FIRMWARE="no" # Do not install full firmware for UEFI boards

	# Also make the output qcow2 larger; KubeVirt does not resize/overlay qcow2's for container-disks
	display_alert "Setting large sparse qcow2" "${EXTENSION} ${K8S_MAJOR_MINOR}" "info"
	declare -g QCOW2_RESIZE_AMOUNT="+50G" # resize the qcow2 image to be 50G bigger

	return 0
}

# A separate 900-later hook to override UEFISIZE set by grub extension
# @TODO: this breaks UEFI, it can't find the ESP. Why?!
#function extension_prepare_config__900_k8s() {
#	# Reduce the size of the ESP/EFI partition, makes total raw image smaller (shouldnt affect qcow2)
#	declare -g UEFISIZE=8 # GRUB takes only a few kb, but 1mb causes trouble
#}

function pre_customize_image__600_k8s_containerd() {
	display_alert "Adding k8s containerd infra from rpardini/k8s-worker-containerd" "${EXTENSION} ${K8S_MAJOR_MINOR}" "info"

	declare latest_release_version
	latest_release_version=$(curl -sL "https://api.github.com/repos/armsurvivors/k8s-worker-containerd/releases/latest" | jq -r '.tag_name')

	declare deb_file down_url down_dir full_deb_path

	deb_file="k8s-worker-containerd_${ARCH}_${RELEASE}.deb"
	down_url="https://github.com/armsurvivors/k8s-worker-containerd/releases/latest/download/${deb_file}"

	down_dir="${SRC}/cache/k8s-worker-containerd"
	mkdir -p "${down_dir}"

	full_deb_path="${down_dir}/${latest_release_version}_${deb_file}"

	if [[ ! -f "${full_deb_path}" ]]; then
		display_alert "Will download ${full_deb_path} from latest release..." "${EXTENSION} ${K8S_MAJOR_MINOR}" "info"
		wget --progress=dot:mega --local-encoding=UTF-8 --output-document="${full_deb_path}.tmp" "${down_url}"
		mv -v "${full_deb_path}.tmp" "${full_deb_path}"
	fi

	# Copy to the image (at /root)
	cp -v "${full_deb_path}" "${SDCARD}/root/${deb_file}"
	# Install into image...
	chroot_sdcard_apt_get_install "/root/${deb_file}"
	# Remove from root
	rm -v "${SDCARD}/root/${deb_file}"

	# Check by running it under chroot
	display_alert "Containerd version" "${EXTENSION} ${K8S_MAJOR_MINOR}" "info"
	chroot_sdcard containerd --version

	# Enable its systemd service
	chroot_sdcard systemctl enable containerd.service

	# Configure containerd to use systemd cgroup driver
	mkdir -p "${SDCARD}"/etc/containerd # Ubuntu version does not create it by default
	chroot_sdcard containerd config default > "${SDCARD}"/etc/containerd/config.toml

	# Keep a copy of the original config
	cp -v "${SDCARD}"/etc/containerd/config.toml "${SDCARD}"/etc/containerd/config.toml.orig

	# Manipulating .toml in bash is even worse than YAML. This should NOT be done here.
	if grep -q SystemdCgroup "${SDCARD}"/etc/containerd/config.toml; then
		# If it's already there make sure it's on
		display_alert "Containerd config already has SystemdCgroup" "${EXTENSION} ${K8S_MAJOR_MINOR}" "info"
		sed -i -e 's/SystemdCgroup = false/SystemdCgroup = true/' "${SDCARD}"/etc/containerd/config.toml
	else
		# Terrible hack to add SystemdCgroup.
		display_alert "Adding SystemdCgroup to containerd config" "${EXTENSION} ${K8S_MAJOR_MINOR}" "info"
		sed -i -e 's/runtimes.runc.options]/runtimes.runc.options]\n            SystemdCgroup = true/' "${SDCARD}"/etc/containerd/config.toml
	fi

	# Show the resulting config using Armbian's batcat
	display_alert "Containerd config.toml" "${EXTENSION} ${K8S_MAJOR_MINOR}" "info"
	run_tool_batcat "${SDCARD}"/etc/containerd/config.toml

	display_alert "Config cri-tools to use containerd..." "${EXTENSION} ${K8S_MAJOR_MINOR}" "info"
	cat <<- EOD > "${SDCARD}"/etc/crictl.yaml
		runtime-endpoint: unix:///var/run/containerd/containerd.sock
	EOD
	run_tool_batcat "${SDCARD}"/etc/crictl.yaml

	return 0
}

function pre_customize_image__k8s_settings() {
	display_alert "Configuring systemd-network to not interefere with Cilium..." "${EXTENSION} ${K8S_MAJOR_MINOR}" "info"
	# https://docs.cilium.io/en/stable/operations/system_requirements/#systemd-based-distributions
	cat <<- EOD > "${SDCARD}"/etc/systemd/networkd.conf
		[Network]
		ManageForeignRoutes=no
		ManageForeignRoutingPolicyRules=no
	EOD

	display_alert "Module br_netfilter ..." "${EXTENSION} ${K8S_MAJOR_MINOR}" "info"
	cat <<- EOF > "${SDCARD}"/etc/modules-load.d/k8s.conf
		br_netfilter
	EOF

	display_alert "Tuning bridge-nf-call-iptables/ip6tables in sysctl..." "${EXTENSION} ${K8S_MAJOR_MINOR}" "info"
	cat <<- EOF > "${SDCARD}"/etc/sysctl.d/k8s.conf
		net.bridge.bridge-nf-call-iptables = 1
		net.bridge.bridge-nf-call-ip6tables = 1
		net.ipv4.ip_forward = 1
		net.ipv6.conf.all.forwarding = 1
		net.ipv6.conf.all.disable_ipv6 = 0
		net.ipv4.tcp_congestion_control = bbr
		vm.overcommit_memory = 1
		kernel.panic = 10
		kernel.panic_on_oops = 1
		fs.inotify.max_user_instances = 524288
		fs.inotify.max_user_watches = 524288
	EOF

	return 0
}

function pre_customize_image__800_k8s_itself() {
	display_alert "Adding k8s binaries version ${K8S_MAJOR_MINOR}" "${EXTENSION} ${K8S_MAJOR_MINOR}" "info"

	# Grab the GPG key
	mkdir -p "${SDCARD}"/etc/apt/keyrings
	curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_MAJOR_MINOR}/deb/Release.key" | gpg --dearmor -o "${SDCARD}"/etc/apt/keyrings/kubernetes-apt-keyring.gpg

	# Add the SUSE-OBS repository
	echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_MAJOR_MINOR}/deb/ /" > "${SDCARD}/etc/apt/sources.list.d/kubernetes.list"
	chroot_sdcard_apt_get_update

	# Install the k8s binaries
	chroot_sdcard_apt_get_install "kubeadm" "kubelet" "kubectl"

	# Check by running it under chroot
	chroot_sdcard kubeadm version

	# Enable the kubelet service
	chroot_sdcard systemctl enable kubelet.service

	# Hold the k8s packages
	chroot_sdcard apt-mark hold kubeadm kubelet kubectl

	return 0
}

# crap hack to slim down image by using debfoster. this will be an eternal chase as upstreams change.
# unfortunately armbian's "minimal" is untrustworthy/not-minimal, and "cli" is too much
function pre_customize_image__400_k8s_debfoster() {
	display_alert "HACK: Cleaning up unused packages via debfoster" "${EXTENSION}" "info"

	declare -a debfoster_keepers=() install_pre_debfoster=()

	install_pre_debfoster+=("debfoster") # we need to install it first

	debfoster_keepers+=(
		cloud-init
		cloud-initramfs-growroot
		busybox # needed for growroot inside initrd, lest 'sed not found'
		toilet  # armbian motd et al
		netplan.io
		nfs-common
		openssh-server
		sudo
	)

	case "${DISTRIBUTION}-${RELEASE}" in
		"Debian-"*)
			display_alert "Debian: usr-is-merged, systemd-resolved" "keeping" "info"
			install_pre_debfoster+=("usr-is-merged") # compensate, otherwise missing deps. fix Armbian messup in pkgs
			debfoster_keepers+=("systemd-resolved" "usr-is-merged")
			[[ "${BRANCH}" == "ddk" ]] && debfoster_keepers+=("linux-image-${ARCH}")
			;;
		"Ubuntu-"*)
			display_alert "Ubuntu: python3-apt" "keeping" "info"
			debfoster_keepers+=("python3-apt") # needed for grub-mkconfig, noble+ ?
			[[ "${BRANCH}" == "ddk" ]] && debfoster_keepers+=("linux-image-generic")
			;;
	esac

	case "${ARCH}" in
		"arm64")
			debfoster_keepers+=("armbian-bsp-cli-uefi-arm64-${BRANCH}-grub-mluc-cloud" "grub-efi-arm64")
			[[ "${BRANCH}" != "ddk" ]] && debfoster_keepers+=("linux-dtb-${BRANCH}-arm64" "linux-image-${BRANCH}-arm64")
			;;
		"amd64")
			debfoster_keepers+=("armbian-bsp-cli-uefi-x86-${BRANCH}-grub-mluc-cloud" "grub-pc" "grub-efi-amd64-bin")
			[[ "${BRANCH}" != "ddk" ]] && debfoster_keepers+=("linux-image-${BRANCH}-x86")
			;;
	esac

	display_alert "Debfoster: installing" "Installing '${install_pre_debfoster[*]}'" "info"
	chroot_sdcard_apt_get_update
	chroot_sdcard_apt_get_install "${install_pre_debfoster[@]}"

	display_alert "Debfoster: setting keepers" "Keeping '${#debfoster_keepers[*]}' packages" "info"
	chroot_sdcard debfoster --force --mark-only "${debfoster_keepers[@]}"

	display_alert "Debfoster: removing unused packages" "running debfoster!" "info"
	chroot_sdcard debfoster --force --option "'RemoveCmd=apt-get --purge --autoremove -y remove'" -o "UseRecommends=no"

	# Show a list of installed packages and their sizes after debfoster is done -- "what is left?"
	display_alert "Debfoster: list of installed packages and their sizes" "after debfoster" "info"
	chroot_sdcard dpkg-query -Wf '\${Installed-Size}\\t\${Package}\\n' "|" sort -n
}

function post_customize_image__900_k8s_cleanup_apt_stuff() {
	display_alert "Cleaning up apt package lists and cache" "${EXTENSION}" "info"
	chroot_sdcard "apt-get clean && rm -rf /var/lib/apt/lists"

	# override the core function that would bring those back
	function apt_lists_copy_from_host_to_image_and_update() {
		display_alert "Skipping apt lists copy from host to image and update" "${EXTENSION}" "info"
	}
}
