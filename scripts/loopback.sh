#!/bin/bash

source inc/utilities.sh
set -ex

#
# Environment variables
DISK_IMG= ;
DISK_TYPE="mmc"
DISK_SWAP=0

ROOT_DEV= ;
BOOT_DEV= ;
SWAP_DEV= ;

ROOT_PATH="$(mktemp -d)"

ROOT_FSYS="btrfs"
BOOT_FSYS="vfat"

DEVMAPPER=0
OVERWRITE=0

#
# Command usage
function usage() {
	cat <<-ENDHELP
	-n, --name      :: Image file descriptor
	-s, --size      :: Image size
	-r, --root      :: Chroot path
	                => ${ROOT_PATH}
	-s, --no-swap   :: Turn off swap (todo)
	-S, --swap      :: Turn on swap (todo)
	--sata          :: Use sata disk type
	--mmc           :: Use mmc disk type
	-D, --disk-type :: Set disk typeP
	-h, --help      :: This message
	ENDHELP
	exit 1
}

#
# Parse command options
getopt -o n:s:r:D:Oh -Q \
	-l name:,size:,root:,sata,mmc,disk-type:,overwrite,help -- "$@"

while true; do
	case "$1" in
		-n|--name) 			DISK_NAME="$2"; 							shift 2;;
		-s|--size) 			DISK_SIZE="$(to_bytes $2)"; 	shift 2;;
		-r|--root) 			ROOT_PATH="$2"; 							shift 2;;
		-O|--overwrite) OVERWRITE=1;									shift 1;;
		-h|--help) 			usage;												shift 1;;
		-s|--no-swap) 	DISK_SWAP=0;									shift 1;;
		-S|--swap)			DISK_SWAP=1;		 							shift 1;;
		--sata)					DISK_TYPE="sata"; 						shift 1;;
		--mmc)			 		DISK_TYPE="mmc";							shift 1;;
		-D|--disk-type)	DISK_TYPE="$2";								shift 2;;


		# Disk Encryption
		-E|--disk-encrypt)
			# @TODO Default setup
			;;
		--disk-encrypt-hash) 		DISK_ENCRYPT_PASSHASH="$2"; shift 2;;
		--disk-encrypt-keysize) DISK_ENCRYPT_KEYSIZE="$2";	shift 2;;
		--disk-encrypt-cipher)	DISK_ENCRYPT_CIPHER="$2"; 	shift 2;;
		*)																									break	;;
	esac
done




function is_block_device() {
	[[ -z "${DISK_NAME}" ]] && return 1
	[[ -e "${DISK_NAME}" ]] && [[ "$(stat ${DISK_NAME})" = "block special file" ]]
}

function is_disk_image() {
	[[ -z "${DISK_NAME}" ]] && return 1
	is_block_device				 && return 1
	return 0
}

#
# Create disk image
function create_disk_image() {
	if ! is_disk_image; then
		echo "'${DISK_NAME}' is not a disk image."
		echo "more likely it is a block device."
		return 0
	fi

	if [[ -z "${DISK_NAME}" ]] || [[ ${DISK_SIZE} -lt 1 ]]; then
		fail "Unable to create disk image '${DISK_NAME}' with less then 1 byte."
		return 1
	fi

	if [[ -e "${DISK_NAME}" ]] && [[ ${OVERWRITE} -eq 0 ]]; then
		fail "Will not overwrite existing disk image '${DISK_NAME}'"
		fail "without the command option '--overwrite'"
		return 0
	fi

	echo "Creating disk image '${DISK_NAME}' with size '${DISK_SIZE}'."
	if ! truncate -s "${DISK_SIZE}" "${DISK_NAME}"; then
		fail "Failed to create disk image '${DISK_NAME}'"
		return 1
	fi

	DEVMAPPER=1
	return 0
}


#
# Unmount Disk
function unmount_disk() {
	if ! is_block_device; then
		fail "Block device '${DISK_NAME}' was not found!"
		return 0
	fi

	echo "Ensuring disk '${DISK_NAME}' is unmounted."
	for mnt in $(grep "${DISK_NAME}" /proc/mounts | awk '{print $2}' | sort -ru); do
		umount "${DISK_NAME}" 2>/dev/null || fail "Unable to unmount ${DISK_NAME}!"
	done
}

partition_disk() {
	# @TODO: Add check for already partifioned disk
	if [[ ${OVERWRITE} -eq 0 ]]; then
		fail "Refused to partition already partitioned disk."
		return 1
	fi

	if ! [[ -e "${DISK_NAME}" ]]; then
		fail "Could not find disk file descriptor or disk image!"
		fail "Shoot. That means something broke in the code."
		fail "If your tech savy could you take a look and submit a pull request?"
		return 1
	fi

	case "x${DISK_TYPE}" in
		xmmc)
			disksig=4e6f764d
			swapsize=+32M
			;;
		xsata)
			disksig=4e6f7653
			swapsize=+4G
			;;
		*)
			fail "Don't understand disk type '${DISK_TYPE}'"
			fail "The available types are '--sata' or '--mmc'"
			return 1
			;;
	esac

	bootsize=+32M

	fdisk ${DISK_NAME} -C32 -H32 <<-EOF
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
	if [[ ${DEVMAPPER} -eq 0 ]] || is_block_device ${DISK_NAME}; then
		echo "No need to map non disk image to /dev/mapper."
		return 0
	fi

	DISK_IMG="${DISK_NAME}"
	DISK_NAME=$(kpartx -s -v -a "${DISK_NAME}" | cut -d' ' -f8 | uniq | grep loop)

	# Check that kpartx returned properly
	stat=$?; if [[ $stat -ne 0 ]]; then
		fail "Unable to map disk image '${DISK_IMG}' to /dev/mapper"
		fail "kpartx returned error code '$stat'"
		return 1
	fi

	# Ensure user is aware of the image mapping
	echo "disk image connected to devmapper"
	echo "disk image '${DISK_IMG}' as '${DISK_NAME}'"
	return 0
}

function devmapper_disk() {
	echo "determining disks..."

	if [[ ${DEVMAPPER} -eq 1 ]]; then
		base="$(echo "${DISK_NAME}" | cut -d/ -f3)"
		DISK_NAME="/dev/mapper/${base}p"
	elif grep -q mmcblk <<<"${DISK_NAME}"; then
		DISK_NAME="${DISK_NAME}p"
	fi

	BOOT_DEV=${DISK_NAME}1
	echo -e "\tboot => $BOOT_DEV"

	if [[ ${DISK_SWAP} -gt 0 ]]; then
		SWAP_DEV=${DISK_NAME}2
		ROOT_DEV=${DISK_NAME}3
		echo -e "\tswap => $SWAP_DEV"
	else
		ROOT_DEV=${DISK_NAME}2
	fi

	echo -e "\troot => $ROOT_DEV"
}

function encrypt_disk() {

	printf "disk encryption... "

	# Check if encryption dependencies were provided
	if ! ([[ -n "${DISK_ENCRYPT_CIPER}" ]] && \
				[[ -n "${DISK_ENCRYPT_KEYSIZE}" ]] && \
				[[ -n "${DISK_ENCRYPT_PASSHASH}" ]]); then
		echo "disabled"
		return 0
	else
		echo "enabled"
	fi

	printf "Setting up an encypted device... "

	# Map the swap partition as encrypted
	if [[ ${DISK_SWAP} -gt 0 ]]; then
		cryptsetup -d /dev/urandom create crypt-swap ${SWAP_DEV}
		SWAP_DEV=/dev/mapper/crypt-swap
		echo "with swap"
	else
		echo "without swap"
	fi

	# Map the root parition as encrypted
	cryptsetup luksFormat				 \
		-h ${DISK_ENCRYPT_PASSHASH} \
		-c ${DISK_ENCRYPT_CIPHER}	 \
		-s ${DISK_ENCRYPT_KEYSIZE}	\
		${ROOT_DEV}

	# Map the partition as encrypted
	cryptsetup luksOpen ${ROOT_DEV} crypt-root
	ROT_DEV=/dev/mapper/crypt-root
}

function mount_disk() {
	if [[ ${OVERWRITE} -gt 0 ]]; then
		mkfs.${BOOT_FSYS} ${BOOT_DEV} 									 || \
			fail "Unable to make boot partition"					 || \
			return 1

		if [[ ${DISK_SWAP} -gt 0 ]]; then
			mkswap -f ${SWAP_DEV} 												 || \
		 	fail "Unable to make swap on ${SWAP_DEV}"			 || \
			return 1
		fi

		mkfs.${ROOT_FSYS} ${ROOT_DEV} 								   || \
			fail "Unable to make root filesystem"					 || \
			return 1
	fi

	mkdir -p "${ROOT_PATH}" 													 || \
		fail "Unable to create mount directory for root" || \
		return 1

	mount ${ROOT_DEV} ${ROOT_PATH} 										 || \
		fail "Unable to mount new root filesystem"			 || \
		return 1

	mkdir -p "${ROOT_PATH}/boot" 											 || \
		fail "Unable to create mount directory for boot" || \
		return 1

	mount ${BOOT_DEV} "${ROOT_PATH}/boot" 			 			 || \
		fail "Unable to mount new boot filesystem" 			 || \
		return 1
}

unmount_disk 				|| exit 1
create_disk_image 	|| exit 1
partition_disk		 	|| exit 1
prepare_disk_image 	|| exit 1
devmapper_disk 			|| exit 1
encrypt_disk        || exit 1
mount_disk          || exit 1
