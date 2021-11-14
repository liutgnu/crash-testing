#!/bin/bash

ARCH_LIST=("ARM" "ARM64" "X86" "X86_64" "PPC64" "S390X")
ARCH_REGEX_LIST=("armv[0-9]|ARM," "aarch64" "80386|i686" "x86-64|x86_64" "64-bit PowerPC|ppc64le" "IBM S/390|s390x")
ARCH_REGEX=""
VMLINUX_REGEX="vmlinux|executable"
VMCORE_REGEX="core|dump"

function generate_dumplist()
{
	TOP_DIR=$1
	ARCH=$2
	DUMPLIST_FILE=$3
	FILE_NAME=$(basename ${BASH_SOURCE[0]})

	usage()
	{
		echo "Usage:"
		echo "$FILE_NAME <vmcore_dir> <arch> [dumplist_file]"
		echo
		echo "Optional archs: ${ARCH_LIST[@]}"
		echo
		echo "Automatically generate a list file for indexing arch-specific vmlinux"
		echo "and vmcores within vmcore_dir and its subdirectories, the list file"
		echo "will be used by crash_test.sh later."
		echo
		echo "vmcore_dir is the top directory which holds vmcore and vmlinux in"
		echo "its subdirectories. The ideal vmcore directory structure is:"
		echo "      vmcore_dir"
		echo "      |-- subdir1"
		echo "      |   |-- vmlinux1"
		echo "      |   |-- vmcore1_a"
		echo "      |   \`-- vmcore1_b"
		echo "      \`-- subdir2"
		echo "          |-- vmlinux2"
		echo "          \`-- vmcore2"
		echo
		echo "If dumplist_file specified, the output will be stored in dumplist_file,"
		echo "else be outputed to stdout."
	}

	if [[ -z $TOP_DIR || -z $ARCH ]]; then
		usage
		exit 1
	fi

	if [[ ! " ${ARCH_LIST[@]} " == *" $ARCH "* ]]; then
		echo "Wrong arch \"$ARCH\"" 1>&2
		echo "Optional archs: ${ARCH_LIST[@]}" 1>&2
		exit 1
	fi

	for ((i=0;i<${#ARCH_LIST[@]};i++)); do
		if [[ "${ARCH_LIST[$i]}" == "$ARCH" ]]; then
			ARCH_REGEX="${ARCH_REGEX_LIST[$i]}"
		fi
	done

	if [[ ! -z $TOP_DIR && -d $TOP_DIR ]]; then
		TOP_DIR=$(readlink -f $TOP_DIR)
	else
		echo "Directory $TOP_DIR not exist!"
		exit 1
	fi

	SUB_DIRS=($(cd $TOP_DIR && find ./ -type d))

	[ -z $DUMPLIST_FILE ] && echo "DUMPLIST_START" || \
		echo "DUMPLIST_START" > $DUMPLIST_FILE
	for DIR in ${SUB_DIRS[@]}; do
		VMCORE=()
		VMLINUX=()

		cd $TOP_DIR/$DIR
		FILES=$(find . -maxdepth 1 -type f -o -type l)
		for FILE in $FILES; do
			FILE_LOWER=$(echo $FILE | tr '[:upper:]' '[:lower:]')
			if [[ $FILE_LOWER =~ $VMLINUX_REGEX || \
			$(file -z $FILE) =~ $VMLINUX_REGEX ]]; then
				if [[ $FILE_LOWER =~ $ARCH_REGEX || \
				$(file -z $FILE) =~ $ARCH_REGEX ]]; then
					VMLINUX+=(${FILE:2})
					continue
				fi
			fi

			if [[ $FILE_LOWER =~ $VMCORE_REGEX || \
			$(file -z $FILE) =~ $VMCORE_REGEX ]]; then
				if [[ $FILE_LOWER =~ $ARCH_REGEX || \
				$(file -z $FILE) =~ $ARCH_REGEX ]]; then
					VMCORE+=(${FILE:2})
				fi
			fi
		done
		cd ~-

		if [[ ${#VMLINUX[@]} -gt 1 ]]; then
			echo "More than 1 vmlinux exist in $TOP_DIR/${DIR:2}, skipping the dir..." 1>&2
			continue
		fi

		[ $DIR == "./" ] && DIR="" || DIR=${DIR:2}"/"
		if [[ ${#VMLINUX[@]} -eq 1 && ${#VMCORE[@]} -ne 0 ]]; then
			for((i=0;i<${#VMCORE[@]};i++)); do
				[ -z $DUMPLIST_FILE ] && echo $DIR${VMCORE[$i]} $DIR${VMLINUX[0]} || \
					echo $DIR${VMCORE[$i]} $DIR${VMLINUX[0]} >> $DUMPLIST_FILE
			done
		fi
	done
	[ -z $DUMPLIST_FILE ] && echo "DUMPLIST_END" || \
		echo "DUMPLIST_END" >> $DUMPLIST_FILE

	if [[ ! -z $DUMPLIST_FILE && -z $TIMESTAMP ]]; then
		echo "Create $DUMPLIST_FILE done"
		echo "------"
		echo "You can pass the following options to crash_test.sh for crash testing:"
		echo "-D $TOP_DIR -d $DUMPLIST_FILE"
	fi
}

function get_crash_arch()
{
	# $1: crash bin
	local ARCH_STR=$(file $1)

	for((i=0;i<${#ARCH_LIST[@]};i++)); do
		[[ $ARCH_STR =~ ${ARCH_REGEX_LIST[$i]} ]] && \
		echo ${ARCH_LIST[$i]} && return
	done

	echo "Unsupported crash arch" 1>&2
	echo "Optinal arch: ${ARCH_LIST[@]}" 1>&2
	exit 1
}

[[ -z $TIMESTAMP ]] && generate_dumplist $1 $2 $3