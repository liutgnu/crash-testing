#!/bin/bash

LOG1=$1
LOG2=$2
START_CASE=$3
END_CASE=$4
FILE_NAME=$(basename ${BASH_SOURCE[0]})
CURRENT_DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd -P)

usage()
{
	echo "Usage:"
	echo "$FILE_NAME <crash.log> <crash2.log> [<start case> <end case>]"
	echo
	echo "Tool for analyzing crash-testing original logs diff. The 2 files can"
	echo "be text file or gzip compressed file. Currently it will output the diff"
	echo "chuk when lines are different, which indicates the chuk is more likely"
	echo "to be a regression. For example:"
	echo 
	echo "Chuk will not be output:"
	echo "<         sigaction: aaaac6836480"
	echo "<     gdb_sigaction: aaaac6836518"
	echo "---"
	echo ">         sigaction: e07340"
	echo ">     gdb_sigaction: e073d8"
	echo
	echo "Chuk will be output:"
	echo "1198222a1194077,1194079"
	echo ">       wait_queue_entry_private: 8"
	echo ">           wait_queue_head_head: 8"
	echo ">         wait_queue_entry_entry: 24"
}

if [[ "$START_CASE" == "" && "$END_CASE" != "" ]]; then
	echo -e "Invalid start case and end case range\n"
	usage
	exit 1
fi

if [[ "$START_CASE" != "" && "$END_CASE" == "" ]]; then
	echo -e "Invalid start case and end case range\n"
	usage
	exit 1
fi

if [[ $LOG1 == "" || ! -f $LOG1 ]]; then
	echo -e "Error \"$LOG1\" not exist!\n"
	usage
	exit 1
fi

file $LOG1 | grep "gzip" 2>&1 >/dev/null
if [ $? -eq 0 ]; then
	[ "$START_CASE" == "" ] && LOG1="<(zcat $LOG1)" ||
		LOG1="<($CURRENT_DIR/split_test_output.sh $LOG1 $START_CASE $END_CASE)"
else
	[ "$START_CASE" == "" ] && LOG1="<(cat $LOG1)" ||
		LOG1="<($CURRENT_DIR/split_test_output.sh $LOG1 $START_CASE $END_CASE)"
fi

if [[ $LOG2 == "" || ! -f $LOG2 ]]; then
	echo -e "Error \"$LOG2\" not exist!\n"
	usage
	exit 1
fi

file $LOG2 | grep "gzip" 2>&1 >/dev/null
if [ $? -eq 0 ]; then
	[ "$START_CASE" == "" ] && LOG2="<(zcat $LOG2)" ||
		LOG2="<($CURRENT_DIR/split_test_output.sh $LOG2 $START_CASE $END_CASE)"
else
	[ "$START_CASE" == "" ] && LOG2="<(cat $LOG2)" ||
		LOG2="<($CURRENT_DIR/split_test_output.sh $LOG2 $START_CASE $END_CASE)"
fi

CMD="diff -EZbBw $LOG1 $LOG2"

eval $CMD | awk '
	function print_array(array, array_len) {
		for (i=0;i<array_len;i++) {
			print array[i];
		}
	}

	BEGIN {
		CHUK_START_REGX="^[0-9a-f,]+$";
		LOG1_CHUK_REGX="^<";
		LOG2_CHUK_REGX="^>";
		CHUK_SEP_REGX="^---";
	}

	$0 ~ CHUK_START_REGX {
		if (log1_line != log2_line) {
			print chuk_start;
			print_array(array, array_index);
		}
		delete array;
		log1_line=0;
		log2_line=0;
		array_index=0;
		chuk_start=$0;
		next;
	}
	
	$0 ~ LOG1_CHUK_REGX {
		log1_line++;
		array[array_index++]=$0;
		next;
	}

	$0 ~ LOG2_CHUK_REGX {
		log2_line++;
		array[array_index++]=$0;
		next;
	}

	$0 ~ CHUK_SEP_REGX {
		array[array_index++]=$0;
		next;
	}

	END {
		if (log1_line != log2_line) {
			print_array(array, array_index);
		}
		delete array;
	}
'
