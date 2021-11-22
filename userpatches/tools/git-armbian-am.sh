#!/usr/bin/env bash

set -e

GIT_TREE="/Volumes/LinuxDevImage/linux/linux-stable"
PATCHES_DIR="/Volumes/LinuxDevImage/armbian/armbian_rpardini_work/patch/kernel/archive/meson64-5.10"
TEMP_DIR="/Volumes/LinuxDevImage/linux/armbian_patches_temp"
TEMP_BRANCH_FOR_CLEANING="linux-5.10.y"
TARGET_BRANCH="armbian_patches_5.10"
CLEAN_UPSTREAM_BRANCH="rpardini/stable-5.10.67-clean"

echo "Git tree: ${GIT_TREE}"
echo "Patches dir: ${PATCHES_DIR}"
echo "TEMP_DIR: ${TEMP_DIR}"

function apply_patch() {
	ORIG_PATH_FILE_FULL="$1"
	echo "Applying original patch: ${ORIG_PATH_FILE_FULL}"
	PATCH_BASENAME="$(basename "${ORIG_PATH_FILE_FULL}" ".patch")"
	echo "PATCH_BASENAME: ${PATCH_BASENAME}"

	DEST_TEMP_PATCH="${TEMP_DIR}/${PATCH_BASENAME}.patch"

	# Check  that the patch is a mbox-formatted thing?
	if grep -q "^Subject:" "${ORIG_PATH_FILE_FULL}"; then
		echo "MBOX - Patch is already in mbox format. Applying directly."
		cp "${ORIG_PATH_FILE_FULL}" "${DEST_TEMP_PATCH}"
	else
		echo "NO MBOX - Patch is a floating diff. Synthesize mbox header..."
		create_mbox_header "${ORIG_PATH_FILE_FULL}" "${PATCH_BASENAME}" "${DEST_TEMP_PATCH}"
	fi
	echo "WROTE: ${DEST_TEMP_PATCH}"

	actually_apply_patch "${DEST_TEMP_PATCH}" "${PATCH_BASENAME}"

	echo -e "\n"
}

function actually_apply_patch() {
	PATCH_FILE="$1"
	PATCH_BASENAME="$2"

	echo "* Will apply '${PATCH_BASENAME}' from '${PATCH_FILE}'"

	# Try git am first. It may fail, so keep the return code?
	cd "${GIT_TREE}"
	declare -i GIT_AM_WORKED=0
	git am --no-signoff --no-gpg-sign "${PATCH_FILE}" && GIT_AM_WORKED=1

	if [[ $GIT_AM_WORKED -gt 0 ]]; then
		echo "*** GIT AM WORKED!"
	else
		echo "*** GIT AM FAILED -- do the patch dance"
		patch -p1 -N < "${PATCH_FILE}"
		git add .
		git am --continue
		echo "   *** Patch dance apparently worked!"
	fi

}

function create_mbox_header() {
	SOURCE_PATCH_FILE="$1"
	PATCH_BASENAME="$2"
	TARGET_FILE="$3"

	PATCH_DIR="$(dirname "${SOURCE_PATCH_FILE}")"
	cd "${PATCH_DIR}"

	FIRST_REVISION=$(git log --pretty=oneline --follow "${SOURCE_PATCH_FILE}" | tail -n1)
	LAST_NON_COPY=$(git log --diff-filter=AM --pretty=oneline --follow "${SOURCE_PATCH_FILE}" | head -n1)

	ORIGINAL_SHA="$(echo "${LAST_NON_COPY}" | cut -d " " -f 1)"
	ORIGINAL_FROM_HEADERS_ORIG="$(git show --format=email "${ORIGINAL_SHA}" | grep -e "^From:")"
	ORIGINAL_FROM_HEADERS="$(git show --format=email "${ORIGINAL_SHA}" | grep -e "^From:" | grep "\@" || true)"
	ORIGINAL_DATE_HEADERS="$(git show --format=email "${ORIGINAL_SHA}" | grep -e "^Date:")"
	ORIGINAL_SUBJ_HEADERS_ORIG="$(git show --format=email "${ORIGINAL_SHA}" | grep -e "^Subject:")"
	echo "ORIGINAL_SUBJ_HEADERS_ORIG: '${ORIGINAL_SUBJ_HEADERS_ORIG}'"
	ORIGINAL_SUBJ_HEADERS="$(git show --format=email "${ORIGINAL_SHA}" | grep -e "^Subject:" | sed -n -e 's/^.*\]//p')"
	echo "ORIGINAL_SUBJ_HEADERS: '${ORIGINAL_SUBJ_HEADERS}'"
	ORIGINAL_FROMID_HEADERS="$(git show --format=email "${ORIGINAL_SHA}" | grep -e "^From\ ")"

	HACKED_FROM_HEADERS="${ORIGINAL_FROM_HEADERS}"
	if [[ "a${ORIGINAL_FROM_HEADERS}a" == "aa" ]]; then
		# Great chance that was Igor, try to fix manually?
		if [[ "${ORIGINAL_FROM_HEADERS_ORIG}" =~ "Igor" ]]; then
			echo "*** Original email invalid: '${ORIGINAL_FROM_HEADERS_ORIG}' - found Igor! "
			HACKED_FROM_HEADERS="From: Igor Pecovnik <igor.pecovnik@gmail.com>"
		else
			echo "*** Original email invalid: '${ORIGINAL_FROM_HEADERS_ORIG}' "
			HACKED_FROM_HEADERS="From: UnknownArmbianContributor <unknown.contributor@armbian.com>"
		fi
	fi

	GIT_HISTORY_REF="$(git log --pretty=reference --follow "${SOURCE_PATCH_FILE}")"
	GIT_HISTORY_REF_ADD_MOD="$(git log --diff-filter=AM --pretty=reference --follow "${SOURCE_PATCH_FILE}")"

	cat << EOD > "${TARGET_FILE}"
${ORIGINAL_FROMID_HEADERS}
${ORIGINAL_DATE_HEADERS}
${HACKED_FROM_HEADERS}
Subject: [PATCH] ARMBIAN: ${PATCH_BASENAME}: ${ORIGINAL_SUBJ_HEADERS}

- First git appearance: ${FIRST_REVISION}
- Last non-copy/rename appearance: ${LAST_NON_COPY}
- Author info from: ${ORIGINAL_SHA}
- Original From header: ${ORIGINAL_FROM_HEADERS_ORIG}
- Original Subject header: ${ORIGINAL_SUBJ_HEADERS_ORIG}

- History of add/modify (not copies or renames):
${GIT_HISTORY_REF_ADD_MOD}

- Full git history:
${GIT_HISTORY_REF}

EOD
	echo "--- DEBUG S ---"
	cat "${TARGET_FILE}"
	echo "--- DEBUG E ---"

	cat "${SOURCE_PATCH_FILE}" >> "${TARGET_FILE}"
	echo "Done, mbox synthesized"
}

# Reset temp dir.
[[ -d "${TEMP_DIR}" ]] && rm -rf "${TEMP_DIR}"
mkdir -p "${TEMP_DIR}"

# @TODO: reset the git tree to wanted position
cd "${GIT_TREE}"
echo "Resetting git tree at ${GIT_TREE}"
git am --abort || true
git reset --hard
git clean -xfd
git checkout "${TEMP_BRANCH_FOR_CLEANING}"
git branch -D "${TARGET_BRANCH}" || true
git checkout -b "${TARGET_BRANCH}" "${CLEAN_UPSTREAM_BRANCH}"

echo "Done resetting..."

PATCHES_LIST_SORTED="$(ls -1 "${PATCHES_DIR}/"*.patch | sort -u)"
#echo "List sorted: ${PATCHES_LIST_SORTED}"
while IFS= read -r orig_patch; do
	apply_patch "$orig_patch"
done <<< "${PATCHES_LIST_SORTED}"

echo "DONE! Worked!"
