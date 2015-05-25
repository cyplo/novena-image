#!/bin/bash

#
# Environment variables
DISKTYPE="mmc"
ROOTPATH="$(mktemp -d)"
LOOPBACK=0
OVERWRITE=0

#
# Command usage
function usage() {
	cat <<-ENDHELP
  -n, --name :: Image file descriptor
  -s, --size :: Image size
	-r, --root :: Chroot path
						 => ${ROOTPATH}
	-S, --sata :: Use sata disktype
	-M, --mmc  :: Use mmc disktype
	-D, --disktype :: Set disktype
  -h, --help :: This message
	ENDHELP
}

#
# Parse command options
getopt -o n:s:r:SMD:Oh -Q \
	-l name:,size:,root:,sata,mmc,disktype:,overwrite,help -- "$@"

while true; do
	case "$1" in
		-n|--name) 			DISKNAME="$2"; 	shift 2;;
		-s|--size) 			DISKSIZE="$2"; 	shift 2;;
		-r|--root) 			ROOTPATH="$2"; 	shift 2;;
		-O|--overwrite) OVERWRITE=1		  shift 1;;
		-h|--help) 			usage;			    shift 1;;
		-S|--sata)      DISKTYPE="sata" shift 1;;
		-M|--mmc)       DISKTYPE="mmc"  shift 1;;
		-D|--disktype   DISKTYPE="$2";  shift 2;;
		*)                        			break  ;;
	esac
done


#
# Utilities
function fail() { echo "$@" 1>&2; return 1; }
function stat() { command stat -L -c '%F' "$@"; }


function is_block_device() {
	local diskname
	read 	diskname <<<"$@"

	[[ -z "${diskname}" ]] && return 1
	[[ -e "${diskname}" ]] && [[ "$(stat ${diskname})" = "block special file" ]]
}

function is_disk_image() {
	local diskname
	read  diskname <<<"$@"

	[[ -z "${diskname}" ]] && return 1
	is_block_device        && return 1
	return 0
}

#
# Create disk image
function create_disk_image() {
	local diskname disksize
	read 	diskname disksize <<<"$@"

	if ! is_disk_image; then
		echo "'${diskname}' is not a disk image."
		echo "more likely it is a block device."
		return 0
	fi

	[[ -z "${diskname}" ]] || [[ ${disksize} -lt 1 ]]; then
		fail "Unable to create disk image '${diskname}' with less then 1 byte."
		return 1
	fi

	if [[ -e "${diskname}" ]] && [[ ${OVERWRITE} -ne 0 ]]; then
		fail "Will not overwrite existing disk image '${diskname}'"
		fail "without the command option '--overwrite'"
		return 1
	fi

	echo "Creating disk image '${diskname}' with size '${disksize}'."
	if truncate "-s${disksize}" "${diskname}"; then
		fail "Failed to create disk image '${diskname}'"
		return 1
	fi

	LOOPBACK=1
	return 0
}


#
# Unmount Disk
function unmount_disk() {
	local diskname
	read 	diskname <<<"$@"

	if ! is_block_device; then
		fail "Block device '${diskname}' was not found!"
		return 1
	fi

	echo "Ensuring disk '${diskname}' is unmounted."
	for mnt in $(grep "${diskname}" /proc/mounts | awk '{print $2}' | sort -ru); do
		umount "${diskname}" 2>/dev/null || fail "Unable to unmount ${diskname}!"
	done
}

partition_disk() {
	local diskname disktype
	read 	diskname disktype <<<"$@"

	# @TODO: Add check for already partifioned disk
	if [[ ${OVERWRITE} -ne 0 ]]; then
		fail "Refused to partition already partitioned disk."
		return 1
	fi

	if [[ -e "${diskname}" ]]; then
		fail "Could not find disk file descriptor or disk image!"
		fail "Shoot. That means something broke in the code."
		fail "If your tech savy could you take a look and submit a pull request?"
		return 1
	fi

	case "x${disktype}" in
		xmmc)
			disksig=4e6f764d
			swapsize=+32M
			;;
		xsata)
			disksig=4e6f7653
			swapsize=+4G
			;;
		*)
			fail "Don't understand disk type '${disktype}'"
			fail "The available types are '--sata' or '--mmc'"
			return 1
			;;
	esac

	fdisk ${diskname} -C32 -H32 <<-EOF
	o
	n
	p
	1

	${bootsize}
	n
	p
	2

	${swapsize}
	n
	p
	3


	t
	1
	b
	t
	2
	82
	x
	i
	0x${disksig}
	r
	w
	q
	EOF

	stat=$?; if [[ $stat -ne 0 ]]; then
		fail "Could not partition disks"
		fail "fdisk returned error code '$stat'"
		return 1
	fi
}

function prepare_disk_image() {
	local diskname
	read 	diskname <<<"$@"

	if [[ ${LOOPBACK} -eq 0 ]] || is_block_device ${diskname}; then
		echo "No need to map non disk image to /dev/mapper."
		return 0
	fi

	DISKNAME=$(partx -s -v -a "${diskname}" | cut -d' ' -f8 | uniq | grep loop)

	stat=$?; if [[ $stat -ne 0 ]]; then
		fail "Unable to map disk image '${diskname}' to /dev/mapper"
		fail "kpartx returned error code '$stat'"
		return 1
	fi

	echo "Mounted disk image via devmapper"
	echo "disk image '${diskname}' as '${DISKNAME}'"
	return 0
}


unmount_disk 					"${DISKNAME}" 							|| exit 1
create_disk_image 		"${DISKNAME}" "${DISKSIZE}" || exit 1
partition_disk 	 			"${DISKNAME}" "${DISKTYPE}" || exit 1
prepare_disk_image    "${DISKNAME}"               || exit 1
