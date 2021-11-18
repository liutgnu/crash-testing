#!/bin/bash

ANALYZE_FILE_NAME=$(basename ${BASH_SOURCE[0]})
CURRENT_DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd -P)

function delete_tmp_files()
{
	rm -f /tmp/.difftmp.*
}

function terminate_and_cleanup()
{
	trap - SIGINT && kill -- -$$ 2>/dev/null;
	delete_tmp_files
	exit 0
}

function diff_chunks()
{
	# $1: The log diff file.
	DIFF_FILE=$1

	TITLE_LINES=($(grep -n -E '\[(Test|Dumpfile|Command) ' $DIFF_FILE | cut -d: -f1))

	CHUNK_ARRAY=()
	for ((i=0;i<${#TITLE_LINES[@]};i++)); do
		CHUNK_ARRAY+=(${TITLE_LINES[$i]})
		if [ $i -gt 0 ]; then
			CHUNK_ARRAY+=(${TITLE_LINES[$i]})
		fi
	done
	CHUNK_ARRAY+=($(($(wc -l $DIFF_FILE | cut -d' ' -f1) + 1)))

	TMPFILE1=$(mktemp /tmp/.difftmp.XXXXXX)
	TMPFILE2=$(mktemp /tmp/.difftmp.XXXXXX)
	TMPFILE3=$(mktemp /tmp/.difftmp.XXXXXX)

	for i in $(seq 0 2 ${#CHUNK_ARRAY[@]}); do
		trap 'terminate_and_cleanup' SIGINT

		CHUNK_START=${CHUNK_ARRAY[i]}
		CHUNK_END=$((${CHUNK_ARRAY[i+1]}-1))
		if [[ -z "$CHUNK_START" ]]; then
			break;
		fi
		sed -n -e "${CHUNK_START}p" $DIFF_FILE

		sed -n "$(($CHUNK_START + 1)),${CHUNK_END}p" $DIFF_FILE > $TMPFILE1
		{
			pcre2grep -M '\[\-(\n|(?!page_cache_hdr).)*?\-\]' $TMPFILE1 | \
			pcre2grep -v -M '^\s+\[\-[0-9a-f \n]+\-\]\s*$' > $TMPFILE2
			exit ${PIPESTATUS[0]}
		} & PID[0]=$!
		{
			pcre2grep -M '\{\+(\n|(?!page_cache_hdr).)*?\+\}' $TMPFILE1 | \
			pcre2grep -v -M '^\s+\{\+[0-9a-f \n]+\+\}\s*$' > $TMPFILE3
			exit ${PIPESTATUS[0]}
		} & PID[1]=$!

		for ((i=0;i<2;i++)); do
			wait -n ${PID[$i]}
			EXIT_VAL[$i]=$?
		done

		if [[ "${EXIT_VAL[0]}" =~ ^[0-1]$ && "${EXIT_VAL[1]}" =~ ^[0-1]$ ]]; then
			diff $TMPFILE2 $TMPFILE3
		else
			# cannot get valid output from pcre2grep, so skip the chunk
			continue
		fi
	done | sed -E '/^\[Command /{$!N;/.*[^-]\]$/!P;D}; /^[0-9a-f,]+/d'

	rm -f $TMPFILE1 $TMPFILE2 $TMPFILE3
}

function do_analyze()
{
	LOG1=$1
	LOG2=$2
	ORIGINAL_DIFF_FILE=$3
	START_CASE=$4
	END_CASE=$5

	trap 'terminate_and_cleanup' SIGINT

	file $LOG1 | grep "gzip" 2>&1 >/dev/null
	if [ $? -eq 0 ]; then
		[ "$START_CASE" == "" ] && LOG1="<(zcat $LOG1 | sed -E 's/^(\[(Command|Test|Dumpfile))/AAA \1/')" ||
			LOG1="<($CURRENT_DIR/split_test_output.sh $LOG1 $START_CASE $END_CASE |
				sed -E 's/^(\[(Command|Test|Dumpfile))/AAA \1/')"
	else
		[ "$START_CASE" == "" ] && LOG1="<(cat $LOG1 | sed -E 's/^(\[(Command|Test|Dumpfile))/AAA \1/')" ||
			LOG1="<($CURRENT_DIR/split_test_output.sh $LOG1 $START_CASE $END_CASE |
				sed -E 's/^(\[(Command|Test|Dumpfile))/AAA \1/')"
	fi

	file $LOG2 | grep "gzip" 2>&1 >/dev/null
	if [ $? -eq 0 ]; then
		[ "$START_CASE" == "" ] && LOG2="<(zcat $LOG2 | sed 's/^\[\(Command\|Test\|Dumpfile\)/AAA \L&/')" ||
			LOG2="<($CURRENT_DIR/split_test_output.sh $LOG2 $START_CASE $END_CASE |
				sed 's/^\[\(Command\|Test\|Dumpfile\)/AAA \L&/')"
	else
		[ "$START_CASE" == "" ] && LOG2="<(cat $LOG2 | sed 's/^\[\(Command\|Test\|Dumpfile\)/AAA \L&/')" ||
			LOG2="<($CURRENT_DIR/split_test_output.sh $LOG2 $START_CASE $END_CASE |
				sed 's/^\[\(Command\|Test\|Dumpfile\)/AAA \L&/')"
	fi
	
	DEC_LOG="<(wdiff $LOG1 $LOG2 | pcre2grep -M '\[\-(\n|.)*?\-\]')"
	INC_LOG="<(wdiff $LOG1 $LOG2 | pcre2grep -M '\{\+(\n|.)*?\+\}')"
	CMD="wdiff -w '' -x '' -y '' -z '' $DEC_LOG $INC_LOG"
	
	TMPFILE=$(mktemp /tmp/.difftmp.XXXXXX)
	eval $CMD > $TMPFILE
	sed -i -E 's/^AAA \[\-(.*)\-\] \{\+.*\+\}/\1/' $TMPFILE
	sed -i -E '/^\[Command /{$!N;/.*[^-]\]$/!P;D}' $TMPFILE

	if [[ "$ORIGINAL_DIFF_FILE" == "-" ]]; then
		diff_chunks $TMPFILE
		rm -f $TMPFILE
	else
		mv $TMPFILE $ORIGINAL_DIFF_FILE
		diff_chunks $ORIGINAL_DIFF_FILE
	fi
}

function format_output_for_each_log_diff()
{
	awk '
	function print_array(array, n) {
		for (i = 0; i < n; i++)
			print(array[i]);
	}

	BEGIN {
		array[0] = "";
		is_failed_case = "";
		test_title = "";
	}

	/^\[Test / {
		if (is_failed_case == "true") {
			printf("\n%s Failed\n", test_title);
			print_array(array, n);
		} else if (is_failed_case == "false") {
			printf("\n%s Pass\n", test_title);
		}
		test_title = $0;
		delete array;
		is_failed_case = "false";
		n = 0;
		array[n] = "";
		next;
	}
	/^\[Command / {
		is_failed_case = "true";
	}
	{array[n++] = $0;}

	END {
		if (is_failed_case == "true") {
			printf("%s Failed\n", test_title);
			print_array(array, n);
		} else if (is_failed_case == "false") {
			printf("%s Pass\n", test_title);
		}
		delete array;
	}'
}

function analyze_log_diff()
{
	LOG1=""
	LOG2=""
	LOG_DIFF_FILE=""
	START_CASE=""
	END_CASE=""

	usage()
	{
		echo "Tool to view log differences for analyzing crash regression issue."
		echo
		echo "Usage:"
		echo "$ANALYZE_FILE_NAME -a <crash.log> -b <crash2.log> [-c <diff.log>] [-x <start case> [-y <end case>]]"
		echo "$ANALYZE_FILE_NAME -c <diff.log> [-x <start case> [-y <end case>]]"
		echo
		echo "-a <LOG1>         crash_testing.sh final output log for crash"
		echo "-b <LOG2>         crash_testing.sh final output log for crash2"
		echo "-c <FILE>         Complete differences for LOG1 and LOG2"
		echo "-x NUM            start case"
		echo "-y NUM            end case, if (x y) both exist, analyze case from x to y;"
		echo "                      if only x exists, only analyze case x; "
		echo "                      if no (x y) exist, analyze all cases."
		echo
		echo "When analyzing from crash.log and crash2.log, if -c <diff.log> presented,"
		echo "the complete differences will be outputed to diff.log. Next time can only"
		echo "give -c <diff.log> to analyze diff for better performance."
	} 1>&2

	while getopts "a:b:c:f:x:y:" OPT; do
		case $OPT in
		a) LOG1="$OPTARG"
		;;
		b) LOG2="$OPTARG"
		;;
		c) LOG_DIFF_FILE="$OPTARG"
		;;
		x) START_CASE="$OPTARG"
		;;
		y) END_CASE="$OPTARG"
		;;
		*) usage && exit 1
		;;
		esac
	done

	[[ -n "$START_CASE" ]] && {
		[[ "$START_CASE" =~ ^[0-9]+$ ]] || {
			echo "Error: START_CASE \"$START_CASE\" is not number" && exit 1
		}
	}

	[[ -n "$END_CASE" ]] && {
		[[ "$END_CASE" =~ ^[0-9]+$ ]] || {
			echo "Error: END_CASE \"$END_CASE\" is not number" && exit 1
		}
	}

	[[ -n "$START_CASE$END_CASE" ]] && {
		[[ "$START_CASE$END_CASE" == "$END_CASE" ]] && {
			echo "Error: only END_CASE present" && usage && exit 1
		}
		[[ "$START_CASE$END_CASE" == "$START_CASE" ]] && {
			END_CASE=$START_CASE
		}
	}
	trap "delete_tmp_files" EXIT

	if [[ -n "$LOG1" || -n "$LOG2" ]]; then
		if [[ -n "$LOG1" && -n "$LOG2" && -f "$LOG1" && -f "$LOG2" ]]; then
			[[ -n "$LOG_DIFF_FILE" ]] && {
				do_analyze $LOG1 $LOG2 $LOG_DIFF_FILE $START_CASE $END_CASE
			} || {
				do_analyze $LOG1 $LOG2 "-" $START_CASE $END_CASE
			}
		else
			usage && exit 1
		fi
	else
		[[ -n "$LOG_DIFF_FILE" && -f "$LOG_DIFF_FILE" ]] && {
			[[ -n "$START_CASE" ]] && {
				TMPFILE=$(mktemp /tmp/.difftmp.XXXXXX)
				$CURRENT_DIR/split_test_output.sh $LOG_DIFF_FILE $START_CASE $END_CASE > $TMPFILE
				diff_chunks $TMPFILE
				rm -f $TMPFILE
			} || {
				diff_chunks "$LOG_DIFF_FILE"
			}
		} || {
			usage && exit 1
		}
	fi | format_output_for_each_log_diff
}

analyze_log_diff $@