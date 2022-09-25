#
# SPDX-License-Identifier: GPL-2.0
# Copyright (c) 2024 Ricardo Pardini <ricardo@pardini.net>
# This file is a part of the Armbian Build Framework https://github.com/armbian/build/
#

## Configuration
declare -g COPY_HEADERS_DEB=yes # do copy the headers .deb to rootfs for easy later install?

# Copies a build linux-headers .deb inside the rootfs at /usr/src/
# Much faster than installing it on rootfs.
post_install_kernel_debs__copy_headers_deb_to_rootfs() {
	[[ "${COPY_HEADERS_DEB}" != "yes" ]] && return 0

	declare -g -A image_artifacts_debs

	declare headers_deb="${DEB_STORAGE}/${image_artifacts_debs["linux-headers"]}"
	if [[ -f "${headers_deb}" ]]; then
		display_alert "Including linux-headers package in image" "/usr/src/" "info"
		run_host_command_logged ls -lah "${headers_deb}"
		run_host_command_logged cp -vp "${headers_deb}" "${SDCARD}"/usr/src/
	else
		if [[ "${BRANCH}" != "ddk" ]]; then
			display_alert "Headers package not found, will not be included in image" "${headers_deb}" "info"
		fi
	fi

}
