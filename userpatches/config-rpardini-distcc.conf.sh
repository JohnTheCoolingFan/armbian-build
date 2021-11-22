# Calculate distcc targets.
declare -A -g DISTCC_TARGETS_HOST_PORT=(
	["n2+"]="192.168.66.26:3632"
	["vim3"]="192.168.66.93:3632"
	["q64a"]="192.168.66.92:3632"
	["s912"]="192.168.66.27:3632"
	["om1"]="192.168.66.95:3632"
)

declare -A -g DISTCC_TARGETS_CORES=(
	["n2+"]=6 # 6 total cores, 2 fast cores
	["vim3"]=6
	["q64a"]=4
	["s912"]=7 # 8 total cores, 4 slow cores, 4 even slower cores
	["om1"]=4
)

declare -a -g DISTCC_TARGETS_SPEED_ORDER=("n2+" "vim3" "s912" "q64a" "om1")
