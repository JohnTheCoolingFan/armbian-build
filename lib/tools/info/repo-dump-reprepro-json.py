#!/usr/bin/env python3

# ‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹
#  SPDX-License-Identifier: GPL-2.0
#  Copyright (c) 2023 Ricardo Pardini <ricardo@pardini.net>
#  This file is a part of the Armbian Build Framework https://github.com/armbian/build/
# ‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹
import logging
import os
import json
import berkeleydb

import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from common import armbian_utils

# Prepare logging
armbian_utils.setup_logging()
log: logging.Logger = logging.getLogger("repo-dump-reprepro-json")

reprepro_db_path = sys.argv[1]

reprepro_packages_db_path = os.path.join(reprepro_db_path, "packages.db")

if not os.path.exists(reprepro_packages_db_path):
	log.error(f"File {reprepro_packages_db_path} does not exist!")
	print(json.dumps({}, indent=4, sort_keys=False))
	sys.exit(0)

log.info(f"Reading reprepro packages db from {reprepro_packages_db_path}...")

all_repo = {}

# use berkeleydb to read the packages.db file

db: berkeleydb.db.DB = berkeleydb.db.DB()
db.open(reprepro_packages_db_path, None, berkeleydb.db.DB_BTREE, berkeleydb.db.DB_RDONLY)

# loop over all the databases in the packages.db file
for db_name in db.keys():
	db_name_str = db_name.decode("utf-8")
	# db_name_str is of the format: "armbian-bookworm|main|amd64"
	# parse it, get the distro (arch is irrelevant, every package has to be inspected, cos "all" arch pkgs are linked into every arch individually)
	distro = db_name_str.split("|")[0]
	log.info(f"Reading database {db_name} {db_name_str}...")
	# open the database with that key
	distro_arch_db: berkeleydb.db.DB = berkeleydb.db.DB()
	distro_arch_db.open(reprepro_packages_db_path, db_name_str, berkeleydb.db.DB_UNKNOWN, berkeleydb.db.DB_RDONLY)
	# loop over all the keys in the database
	for key in distro_arch_db.keys():
		# 'key' is null-terminated, so we need to strip it
		key_str = key.decode("utf-8").rstrip("\0")
		# get the value for the key
		value = distro_arch_db[key]
		# 'value' is null-terminated, so we need to strip it
		value_str = value.decode("utf-8").rstrip("\0")
		# The value_str is a standard Debian control file, so we can parse it; we want the "Version" field and the "Armbian-Original-Hash" field
		# The "Version" field is the version of the package, and the "Armbian-Original-Hash" field is the hash of the original .deb file
		control_lines = value_str.split("\n")
		# parse the control file
		control_dict = {}
		for line in control_lines:
			if line == "":
				continue
			if ": " not in line:
				continue
			key, value = line.split(": ", 1)
			control_dict[key] = value
		# get the version and the hash
		version = control_dict["Version"]
		hash = control_dict["Armbian-Original-Hash"]
		package = control_dict["Package"]
		pkg_arch = control_dict["Architecture"]
		# add the version and hash to the all_repo dict
		if distro not in all_repo:
			all_repo[distro] = {}
		if pkg_arch not in all_repo[distro]:
			all_repo[distro][pkg_arch] = {}
		if package not in all_repo[distro][pkg_arch]:
			all_repo[distro][pkg_arch][package] = {}
		all_repo[distro][pkg_arch][package][hash] = version

	# close the database
	distro_arch_db.close()

db.close()

# Dump to json on stdout
repo_json = json.dumps(all_repo, indent=4, sort_keys=False)
print(repo_json)

log.info(f"Done.")
