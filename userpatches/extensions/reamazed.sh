#
# SPDX-License-Identifier: GPL-2.0
# Copyright (c) 2023 Ricardo Pardini <ricardo@pardini.net>
# This file is a part of the Armbian Build Framework https://github.com/armbian/build/
#

function rebuild_amazingfate_on_lunar() {
	# rebuild amazingfate on bookworm

	apt install devscripts build-essential software-properties-common debhelper

	add-apt-repository --enable-source ppa:liujianfeng1994/panfork-mesa --no-update --yes
	add-apt-repository --enable-source ppa:liujianfeng1994/rockchip-multimedia --no-update --yes
	rm -fv /etc/apt/sources.list.d/liujianfeng1994*

	cat <<- EOD > /etc/apt/sources.list.d/amazingfate_sources.list
		deb-src https://ppa.launchpadcontent.net/liujianfeng1994/panfork-mesa/ubuntu/ jammy main
		deb-src https://ppa.launchpadcontent.net/liujianfeng1994/rockchip-multimedia/ubuntu/ jammy main
	EOD

	apt update

	# Get the source package names
	cat /var/lib/apt/lists/ppa.launchpadcontent.net_liujianfeng1994_panfork-mesa_ubuntu_dists_jammy_main_source_Sources /var/lib/apt/lists/ppa.launchpadcontent.net_liujianfeng1994_rockchip-multimedia_ubuntu_dists_jammy_main_source_Sources | grep "^Package: " | cut -d " " -f 2 | xargs echo

	declare -a pkgs=($(cat /var/lib/apt/lists/ppa.launchpadcontent.net_liujianfeng1994_panfork-mesa_ubuntu_dists_jammy_main_source_Sources | grep -e "^Package: " -e "^Version: " | cut -d " " -f 2 | paste -sd '=\n'))

	for pkg in "${pkgs[@]}"; do
		echo "BUILD PKG: $pkg"
		apt build-dep "${pkg}"
		mkdir -p "build-${pkg}" && cd "build-${pkg}"
		apt source --build "${pkg}"
		cd ..
	done

	declare -a pkgs=($(cat /var/lib/apt/lists/ppa.launchpadcontent.net_liujianfeng1994_rockchip-multimedia_ubuntu_dists_jammy_main_source_Sources | grep -e "^Package: " -e "^Version: " | cut -d " " -f 2 | paste -sd '=\n' | grep -v "chromium" ))

	declare -i all_built=0
	while [[ $all_built -eq 0 ]]; do
		echo "STARTING run..."
		find . -type f -name "*.deb" -print0 | xargs -0 apt install -y

		all_built=1
		for pkg in "${pkgs[@]}"; do
			echo "BUILD PKG: $pkg"
			name="${pkg%%=*}"
			version="${pkg##*=}"
			if [[ ! -f "000.built-${name}" ]]; then
				apt build-dep "${name}=${version}"
				mkdir -p "build-${name}" && cd "build-${name}"
				apt source --build "${name}=${version}" && touch "../000.built-${name}" || all_built=0
				cd ..
			else
				echo "SKIPPING ${name}=${version}"
			fi
		done
	done

	# if all built ok...
	#apt install ./*.deb

}
