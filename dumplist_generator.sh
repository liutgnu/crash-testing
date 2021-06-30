#!/bin/bash

TOP_DIR=$1
DUMPLIST_FILE=$2
FILE_NAME=$(basename ${BASH_SOURCE[0]})

usage()
{
	echo "Usage:"
	echo "$FILE_NAME <vmcore_dir> [dumplist_file]"
	echo
	echo "Automatically generate a list file for indexing vmlinux and vmcores"
	echo "within vmcore_dir and its subdirectories, the list file will be used"
	echo "by crash_test.sh later."
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

if [[ -z $TOP_DIR ]]; then
	usage
	exit 1
fi

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
		VMLINUX_REGEX="vmlinux"
		[[ $FILE_LOWER =~ $VMLINUX_REGEX ]] && VMLINUX+=(${FILE:2})

		VMCORE_REGEX="core|dump"
		[[ $FILE_LOWER =~ $VMCORE_REGEX ]] && VMCORE+=(${FILE:2})
	done
	cd ~-

	if [[ ${#VMLINUX[@]} -gt 1 ]]; then
		echo "More than 1 vmlinux exist in ${DIR:2}, skipping..." 1>&2
		continue
	fi

	if [[ ${#VMLINUX[@]} -eq 1 && ${#VMCORE[@]} -ne 0 ]]; then
		for((i=0;i<${#VMCORE[@]};i++)); do
			[ -z $DUMPLIST_FILE ] && echo ${DIR:2}/${VMCORE[$i]} ${DIR:2}/${VMLINUX[0]} || \
				echo ${DIR:2}/${VMCORE[$i]} ${DIR:2}/${VMLINUX[0]} >> $DUMPLIST_FILE
		done
	fi
done
[ -z $DUMPLIST_FILE ] && echo "DUMPLIST_END" || \
	echo "DUMPLIST_END" >> $DUMPLIST_FILE

if [ ! -z $DUMPLIST_FILE ]; then
	echo "Create $DUMPLIST_FILE done"
	echo "------"
	echo "You can pass the following options to crash_test.sh for crash testing:"
	echo "-D $TOP_DIR -d $DUMPLIST_FILE"
fi