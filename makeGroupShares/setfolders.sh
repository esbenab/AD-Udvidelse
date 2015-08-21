#!/bin/bash      
#title           : setfolders.sh
#description     : finds and sets the relevant symlinks for group members.
#author		 	 : (DKSAS30) Esben A Black
#date            : 03 Aug 2015
#version         : 1.0   
#usage		 	 : setfolders.sh
#==============================================================================
set -euf -o pipefail

if [ "$EUID" -ne 0 ]
then
	echo "Program must be run as root"
	exit 1
fi

# echo to stderr
echoerr() {  cat <<< "$@" 1>&2; }

# Make sure any temporary files are secured:
umask 0177
# Make sure we use a secure TMPDIR
TMPDIR="$(mktemp -d /tmp/setgroup.XXXXXX)"

# Make sure that config file exists and are set with permissions allowing only root to modify it
if [ -f "$(dirname "$0")/setgroup.cfg" ]
then
	if [ "$(stat -c "%a %u" "$(dirname "$0")/setgroup.cfg")" != "640 0" ];
	then
		echoerr "Config file $(dirname "$0")/setgroup.cfg must be owned by root at have permissions: 640"
		echoerr "Make sure the file conforms to the description in the header."
		exit 1
	fi;
	source "$(dirname "$0")/setgroup.cfg";
else
	echoerr "Config file $(dirname "$0")/setgroup.cfg must exist and be owned by root, having permissions 640"
	exit 1
fi;
mkdir -p "$ACTIVE_SYMLINKS_FOLDER/logs"
export ACTIVE_SYMLINKS_FOLDER
export AD_SYNC_FOLDER
export TMPDIR
$SASHOME "$(dirname "$0")/group_members.sas" -log "$ACTIVE_SYMLINKS_FOLDER/group_members.log"

# Create targets for the sym-links.
awk 'BEGIN{FS=","} {system("mkdir -p \""$3"\"")}' "$ACTIVE_SYMLINKS_FOLDER/group_symlinks.txt"
awk 'BEGIN{FS=","} {system("chgrp -R "$1" \""$3"\"")}' "$ACTIVE_SYMLINKS_FOLDER/group_symlinks.txt"
# Give groups using a folder rwx access.
awk -v dir=$(dirname "$0") 'BEGIN{FS=","} {system(dir"/setgroup.sh  -R -g "$1" -p rwx \""$3"\"")}' "$ACTIVE_SYMLINKS_FOLDER/group_symlinks.txt"
# For users who have a homedir, make a symlink to the shared folder.
while read -r line; do 
	IFS=',' read -ra ARR <<< "$line"; 
	homedir="/home/${ARR[1]}/"
	if [ ! -d "$homedir" ]; then
		continue
	fi
		# If a file exists where the symlink is to be placed
		if [ -e "$homedir${ARR[2]}" ] 
		then
			# if the file is NOT a symlink
			if [ ! -h "$homedir${ARR[2]}" ]
			then
				ln -s -b "${ARR[3]}" "$homedir${ARR[2]}"
				continue
			else
				rm "$homedir${ARR[2]}"
			fi
		fi
	# create a symlink in place
	ln -s "${ARR[3]}" "$homedir${ARR[2]}"
done < "$TMPDIR/usersInGroups.txt"

