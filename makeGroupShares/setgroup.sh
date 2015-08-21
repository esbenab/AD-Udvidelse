#!/bin/bash      
#title          :setgoup.sh
#description    :Sets the group and rights for a given directory recursively
#author			:Esben A Black (DKSAS30)
#date           :10 juli 2015
#version        :1.0
#usage		 	:setgroup.sh groupname permission_pattern path
#==============================================================================
set -euf -o pipefail
if [ "$EUID" -ne 0 ]
then
	echo "Program must be run as root"
	exit 1
fi

# echo to stderr
echoerr() {  cat <<< "$@" 1>&2; }
# return to original dir on error exit
exitError() {
	popd > /dev/null
	exit $1
}

# Make sure any temporary files are secured:
umask 0177

if [ -f $(dirname "$0")/setgroup.cfg ]
then
	if [ "$(stat -c "%a %u" $(dirname "$0")/setgroup.cfg)" != "640 0" ];
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

function usage(){
printf "Usage: %s: [-R] -g groupname [-g groupname] -p pattern path\n" "$(basename $0)"
echo "-R recursively: apply the changes"
echo "-g groupname: list the groups that should have the pattern described"
}

function argumenterror(){
echo "Argument missing from -$@ option\n $use" 
usage
exitError 2 
}

#set flags
mandetorygroup=false
mandetorypattern=false
recursive=
groupnames=
while getopts ":Rg:p:h" opt; do
	case "$opt" in
		# First we need to check if the settings should be applied recursively
		R)
		recursive=-R
		;;
		# we need to assign groups to the groupnames variable
		g)
		mandetorygroup=true
		if [[ $OPTARG != -* ]]
		then
			if [ -n "$groupnames" ]
			then
				groupnames="$groupnames $OPTARG"
			else 
				groupnames=$OPTARG
			fi
		else
			argumenterror $opt
		fi
		;;
		# we need a permission pattern to apply
		p) 
		if [[ "$OPTARG" != -* ]] && [[ ${OPTARG} =~ [\-0-7r][\-0-7w][\-0-7x].* ]]
		then
			mandetorypattern=true
			pattern=$OPTARG
		else
			if [[ ${OPTARG} =~ [\-0-7r][\-0-7w][\-0-7x].* ]]
			then
				echoerr 'permission patern must match "[r-][w-][x-]" example: r-x or rw-'
				usage
				exitError 1
			fi
			argumenterror $opt
		fi
		;;
		# woops here we catch missing arguments
		\:)	argumenterror $OPTARG
		;;
		# print help
		h)
		usage
		;;
		# say what ? the options was not understood
		\?)
		echoerr "Invalid option: -$OPTARG"
		usage
		;;
	esac
done
echo $@
shift $(($OPTIND - 1))
echo $@
path="$*"
pushd $path > /dev/null

# we make sure that the mandetory options are set
if ! "$mandetorygroup" || ! "$mandetorypattern" || ! [ -d "$path" ]
then
	if ! $mandetorygroup
	then 
		echoerr "At least one group name must be given"
	fi
	if ! $mandetorypattern
	then 
		echoerr "Exactly one permission pattern must be provided"
	fi
	if ! [ -d "$path" ] || [[ "$path" == '/' ]]
	then
		echoerr "A valid path must be given af the last argument"
	fi
	usage
	exitError 1
fi
if [[ "$path" == '/' ]]
then
	echoerr "'/' is not a valid path! do you want to destroy your system?"
	exitError 1
fi

# Set the gihts for on the folders.
chmod $recursive g=rwx,o-rwx "$path"
for batchUser in $BATCHUSERS
do
	setfacl $recursive -d -m u:$batchUser:r-x "$path"
	setfacl $recursive -m u:$batchUser:r-x "$path"
done
setfacl $recursive -d -m g:sas:r-x "$path"
setfacl $recursive -m g:sas:r-x "$path"
for group in $groupnames;
do 
	#	echo $group $path $pattern $recursive
	setfacl $recursive -d -m g:$group:$pattern "$path"
	if [ "$?" != 0 ]
	then 
		echo "The error is most likely in the groupname."
		echo "Failing: setfacl $recursive -d -s g:$group:$pattern \"$path\""
		exitError 1
	fi
	setfacl $recursive -m g:$group:$pattern "$path"
done 
popd > /dev/null
