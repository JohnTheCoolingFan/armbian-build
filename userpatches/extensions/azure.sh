# SPDX-License-Identifier: GPL-2.0
# Copyright (c) 2023 Ricardo Pardini <ricardo@pardini.net>
# This file is a part of the Armbian Build Framework https://github.com/armbian/build/

enable_extension "cloud-metadata"   # Use cloud-metadata
enable_extension "image-output-vhd-azure" # Use .vhd 1024x1024 output

function user_config__700_azure_ami_config() {
	EXTRA_IMAGE_SUFFIXES+=("-azure")                  # global array
	declare -g UEFI_GRUB_TERMINAL="serial console"    # this will go in grub.d config, so Grub displays on serial and console
	declare -g UEFI_GRUB_DISTRO_NAME="ArmbianOnAzure" # To signal this is the rescue rootfs/grub
	declare -g EXTRA_ROOTFS_MIB_SIZE=256              # arm64 image requires a bit more space for Grub?
	declare -g UEFI_ENABLE_BIOS_AMD64="no"            # Disable the BIOS-too aspect of UEFI on amd64, this is just uefi
	declare -g UEFI_EXPORT_KERNEL_INITRD="no"         # do NOT export the initrd and kernel for meta, just like DKB
	display_alert "Azure Virtual Machine" "enabled for ${BOARD} with console at ${SERIALCON}" "info"
}

function post_build_image__910_output_azure_upload_instructions() {
	[[ -z $VHD_SIZE ]] && exit_with_error "VHD_SIZE is not set" # VHD_SIZE is set by output-image-vhd extension
	[[ -z $version ]] && exit_with_error "version is not set"

	declare final_vhd_path="output/images/${version}.img.vhd"
	declare script_path="${DESTIMG}/${version}.azure.sig.create.sh"

	declare disk_arch="x64"
	[[ "${ARCH}" == "arm64" ]] && disk_arch="Arm64"

	cat <<- AZURE_INSTRUCTIONS > "${script_path}"
		#!/bin/bash

		set -e # exit on error

		# Define variables
		declare az_publisher="armbian_publisher_name"
		declare az_offer="armbian_offer_name"
		declare az_sku="armbian_sku_name"
		declare resourceGroup="armbian"
		declare galleryName="armbian_gallery"
		declare imageDefinition="armbian_image_definition"
		declare imageVersion="1.0.0"
		declare region="westeurope"
		declare storageAccount="armbianstorageaccount" # Storage account name must be between 3 and 24 characters in length and use numbers and lower-case letters only
		declare localVHDPath="${final_vhd_path}"
		declare containerName="armbiancontainer" # no underscores or upppercase, apparently
		declare vhdFileName="${version}.img.vhd"
		declare subscriptionId="\$(az account subscription list | jq -r ".[0].subscriptionId")" # get the first subscription from account, hopefully is the correct one

		# Create a resource group if it doesn't exist
		az group create --name \$resourceGroup --location \$region

		# Create a storage account if it doesn't exist
		az storage account create --name \$storageAccount --resource-group \$resourceGroup --location \$region --sku Standard_LRS

		# Create a container in the storage account if it doesn't exist
		az storage container create --name \$containerName --account-name \$storageAccount

		# Upload the local VHD to the container
		az storage blob upload --container-name \$containerName --file \$localVHDPath --name \$vhdFileName --account-name \$storageAccount

		# Get the VHD URI
		vhdUri=\$(az storage blob url --container-name \$containerName --name \$vhdFileName --output tsv --account-name \$storageAccount)

		# Create a Shared Image Gallery if it doesn't exist
		az sig create --resource-group \$resourceGroup --gallery-name \$galleryName --location \$region --subscription \$subscriptionId

		# Create an image definition
		az sig image-definition create --resource-group \$resourceGroup --gallery-name \$galleryName --gallery-image-definition \$imageDefinition --publisher "\$az_publisher" --offer "\$az_offer" --sku "\$az_sku" --os-type Linux --os-state generalized  --architecture "${disk_arch}" --hyper-v-generation V2

		# Create an image version
		az sig image-version create --resource-group \$resourceGroup --gallery-name \$galleryName --gallery-image-definition \$imageDefinition --gallery-image-version \$imageVersion --subscription \$subscriptionId --os-vhd-uri "\$vhdUri" --os-vhd-storage-account "/subscriptions/\$subscriptionId/resourceGroups/imageGroups/providers/Microsoft.Storage/storageAccounts/\$storageAccount" --replica-count 1 --target-regions \$region
	AZURE_INSTRUCTIONS

	display_alert "Script for creating Azure Shared Image Gallery" "created" "info"

}
