#!/usr/bin/env bash

set -e

SRC="$(
	cd "$(dirname "$0")/../.."
	pwd -P
)"
echo "SRC: ${SRC}"

#which gitfaces || pip install -U gitfaces

declare UPDATE_LOG=yes
declare INTERACTIVE=yes
declare GOURCE_DIR="${SRC}/.tmp/gource"
mkdir -p "${GOURCE_DIR}" "${GOURCE_DIR}"/faces
declare combined_log="${GOURCE_DIR}/combined.log"
declare outfile="${GOURCE_DIR}/armbian_gource_$(date "+%Y%m%d%H%M%S")"
declare GIT_BASEDIR="${SRC}"

if [[ ! -f "${combined_log}" ]] || [[ "${UPDATE_LOG}" == "yes" ]]; then
	echo "Updating combined log from git. Wait!"
	cd "${GIT_BASEDIR}"
	gource --output-custom-log "${combined_log}"
	#gitfaces . "${GOURCE_DIR}"/faces

	# (# Replace the usernames as mapped, IFS change in subshell
	# 	IFS="|"
	# 	# shellcheck disable=SC2162
	# 	while read wrong_name name; do
	# 		echo "logfile: ${combined_log} - replacing wrong '${wrong_name}' with right '${name}' "
	# 		gsed -i "s/|$wrong_name|/|$name|/g" "${combined_log}"
	# 	done < "${GOURCE_DIR}/gource_name_replacements.txt"
	# )
fi

echo "Committers:"
# shellcheck disable=SC2002 # no, your cat is useless.
cat "$combined_log" | cut -d "|" -f 2 | sort | uniq -c | sort -n
echo "======================"

#   --highlight-dirs \
#   --file-extensions \

declare -a GOURCE_OPTS=(
	"$combined_log"
	--seconds-per-day "0.2"
	--file-idle-time 2
	--user-image-dir "${GOURCE_DIR}/faces"
	#-1920x1080
	--no-time-travel
	--highlight-users
	#--colour-images
	--file-extensions
	--key
)

if [[ "${INTERACTIVE}" == "yes" ]]; then
	echo "======================"
	gource --help
	echo "======================"
	man gource | cat
	echo "======================"
	echo "Starting gource..."
	gource "${GOURCE_OPTS[@]}" --loop --hide "bloom" #--output-framerate 60 --multi-sampling --fullscreen
else
	# ,filenames ?
	time gource "${GOURCE_OPTS[@]}" --hide "bloom,mouse,progress" --stop-at-end -o - | ffmpeg -y -r 60 -f image2pipe -vcodec ppm -i - -vcodec libx264 -preset medium -pix_fmt yuv420p -crf 1 -threads 0 -bf 0 "${outfile}.mp4"
fi
