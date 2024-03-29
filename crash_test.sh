#!/bin/bash

CURRENT_DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd -P)
FILE_NAME=$(basename ${BASH_SOURCE[0]})
THIS_FILE=$CURRENT_DIR/$FILE_NAME

# Instance output for recording the all output log of CRASH pid instance.
# Junk output for recording the output of CRASH pid instance of
# a specific combination of command list and vmcore dump.
# Final output is report for users.
if [[ $TIMESTAMP == "" ]]; then
    export TIMESTAMP=$(date +%Y-%m-%d-%T)
fi
CRASH_INSTANCE_OUTPUT="/tmp/.crash.log.$TIMESTAMP.$$"
CRASH_FINAL_OUTPUT="/tmp/crash.log.$TIMESTAMP"
CRASH_FINAL_FILTERED_OUTPUT="/tmp/crash_filtered.log.$TIMESTAMP"
CRASH_INSTANCE_JUNK_OUTPUT="/tmp/.crash_junk.log.$TIMESTAMP.$$"
CRASH2_INSTANCE_OUTPUT="/tmp/.crash2.log.$TIMESTAMP.$$"
CRASH2_FINAL_OUTPUT="/tmp/crash2.log.$TIMESTAMP"
CRASH2_FINAL_FILTERED_OUTPUT="/tmp/crash2_filtered.log.$TIMESTAMP"
CRASH2_INSTANCE_JUNK_OUTPUT="/tmp/.crash2_junk.log.$TIMESTAMP.$$"
MERGED_COMMANDS="/tmp/.merged_commands.log.$TIMESTAMP.$$"
DEFAULT_DUMPLIST_FILE="/tmp/dumplist.$TIMESTAMP.$$"
CRASH_INSTANCE_JUNK_OUTPUT_DIFF="/tmp/.crash_diff_junk.log.$TIMESTAMP.$$"
CRASH_INSTANCE_OUTPUT_DIFF="/tmp/.crash_diff.log.$TIMESTAMP.$$"
CRASH_FINAL_OUTPUT_DIFF="/tmp/crash_diff.log.$TIMESTAMP"
COMMANDLIST_INDEX=0
VERBOSE_MODE=TRUE
DIFF_TOOL=""
ALL_ARGS="$@"
# TEMPLATE_PIPE_PREFIX="/tmp/pipe_"
SPLIT_OUTPUT_PREFIX="/tmp/.crash_dumplist_split.$TIMESTAMP."
if [[ $DUMPLIST_INDEX == "" ]]; then
    DUMPLIST_INDEX=0
fi

CRASH=$(which crash)
DUMPLIST_FILE=""
DUMPCORE_TOP_DIR=""
COMMANDLIST_FILE=""
COMMAND_FILE=""
COMMANDS_TOP_DIR=$CURRENT_DIR
DO_LIVE=FALSE
DO_LOCAL=FALSE
VERIFY=FALSE
# TIME_COMMAND='{print $0}'
CRASH2=""
SUDO=
OPTARGS="-s "
USER_SET_STOP_ON_FAILURE=FALSE
CONCURRENCY=""
source $CURRENT_DIR/utils/progress.sh "$TIMESTAMP"
source $CURRENT_DIR/dumplist_generator.sh

function print_useage()
{
    echo
    echo "Useage:"
    echo
    echo "Vmcore test:"
    echo "  $FILE_NAME [OPTS] -D <vmcore_dir> [-d dumplist_file] -c <commandlist_file>"
    echo "  $FILE_NAME [OPTS] -D <vmcore_dir> [-d dumplist_file] -b <command_file>"
    echo "      vmcore_dir concatenate with item of dumplist_file should be the" 
    echo "      absolute path of vmcore, if items of dumplist_file are relative"
    echo "      paths, then vmcore_dir should be applied."
    echo
    echo "Live test:"
    echo "  $FILE_NAME [OPTS] -a -c <commandlist_file>"
    echo "  $FILE_NAME [OPTS] -a -b <command_file>"
    echo
    echo "-f <FILE>    Specify crash, default is \"$(which crash)\" if crash installed"
    echo "-D <DIR>     Specify top dir of vmcore"
    echo "-d <FILE>    Specify dumpcore list file(must)"
    echo "-C <DIR>     Specify top dir of commands, default to current dir"
    echo "-c <FILE>    Specify crash commands list file"
    echo "-b <FILE>    Specify crash commands file"
    echo "                  One of -c and -b is a (must)"
    echo "-a           Live test"
    # echo "-l           (Not inplemented)Local test"
    # echo "-v           (Not inplemented)Need verify the existance of each dumpcore item"
    echo "-s           Stop on failure"
    # echo "-m           More verbose log output"
    echo "-u <NUM>     Run in NUM concurrency"
    echo "-e <FILE>    Specify extra crash for behaviour comparison"
    echo "-o <OPTS>    Specify options for crash (and for extra crash as well if -e exist)"
}

while getopts "f:d:D:C:c:b:alvtTsmu:e:o:" OPT; do
    case $OPT in
        f) CRASH="$OPTARG"
            ;;
        d) DUMPLIST_FILE="$OPTARG"
            ;;
        D) DUMPCORE_TOP_DIR="$OPTARG"
            ;;
        c) COMMANDLIST_FILE="$OPTARG"
            ;;
        C) COMMANDS_TOP_DIR="$OPTARG"
            ;;
        b) COMMAND_FILE="$OPTARG"
            ;;
        a) DO_LIVE=TRUE
	        ;;
        l) DO_LOCAL=TRUE
	        ;;
        v) VERIFY=TRUE
	        ;;
        s) USER_SET_STOP_ON_FAILURE=TRUE
            ;;
        m) VERBOSE_MODE=TRUE
            ;;
        u) CONCURRENCY=$OPTARG
            ;;
        e) CRASH2="$OPTARG"
            ;;
        o) OPTARGS="$OPTARGS""$OPTARG"
            ;;
        *) print_useage && exit 1
            ;;
    esac
done

function delete_tmp_files()
{
    # Only main process can do tmp-files clean up.
    if [[ ! "$CONCURRENT_SUBPROCESS" == "TRUE" ]]; then
        # rm -f $TEMPLATE_PIPE_PREFIX*
        rm -f $SPLIT_OUTPUT_PREFIX*
        rm -f `echo $CRASH_INSTANCE_OUTPUT | \
            sed -E "s/.[0-9]+$/.*/"`
        rm -f `echo $CRASH2_INSTANCE_OUTPUT | \
            sed -E "s/.[0-9]+$/.*/"`
	rm -f `echo $CRASH_INSTANCE_OUTPUT_DIFF | \
	    sed -E "s/.[0-9]+$/.*/"`
        rm -f `echo $CRASH_INSTANCE_JUNK_OUTPUT | \
            sed -E "s/.[0-9]+$/.*/"`
        rm -f `echo $CRASH2_INSTANCE_JUNK_OUTPUT | \
            sed -E "s/.[0-9]+$/.*/"`
        rm -f `echo $CRASH_INSTANCE_JUNK_OUTPUT_DIFF | \
            sed -E "s/.[0-9]+$/.*/"`
        rm -f `echo $MERGED_COMMANDS | \
            sed -E "s/.[0-9]+$/.*/"`
	rm -f '/tmp/.difftmp.*'
        rm -f "$DEFAULT_DUMPLIST_FILE"
        clean_progress
    fi
}
delete_tmp_files

function terminate_and_cleanup()
{
    if [[ ! $CONCURRENT_SUBPROCESS == "TRUE" ]]; then
        echo "The program is terminated by user."
        delete_tmp_files
        trap - SIGTERM SIGINT && kill -- -$$ 2>/dev/null;
    fi
    exit 0
}

function get_dumplist_list_quantity()
{
    # $1: dumplist file
    local DUMPLIST_START_LINE=$(get_linenum_in_file $1 "DUMPLIST_START")
    DUMPLIST_START_LINE=$(($DUMPLIST_START_LINE + 1))
    local DUMPLIST_END_LINE=$(get_linenum_in_file $1 "DUMPLIST_END")
    DUMPLIST_END_LINE=$(($DUMPLIST_END_LINE - 1))
    check_line_results "DUMPLIST" $1
    [ $? -eq 1 ] && echo 0 && return

    local count=0

    while read ARG1 ARG2 EXTRA_ARGS
    do
        if [[ $ARG1 == "#"* || $ARG1 == "" || $ARG1 == "DO_NOT_STOP_ON_FAILURE" ]]; then
            continue
        fi
        ((count++))
    done <<< $(cat $1 | sed -n -e "$DUMPLIST_START_LINE,"$DUMPLIST_END_LINE"p")

    echo $count
}

# The script will generate subprocesses, so terminate them when we
# receive signals.
trap 'terminate_and_cleanup' SIGTERM SIGINT
trap "delete_tmp_files" EXIT

###############Start check inputs####################
if [[ $DUMPLIST_FILE == "" ]]; then
    if [[ $DO_LIVE == "FALSE" ]]; then
        if [[ -z $DUMPCORE_TOP_DIR ]]; then
            echo "vmcore_dir is not specified!" 1>&2
	    print_useage && exit 1
	fi
    else
        DUMPLIST_FILE="$CURRENT_DIR/dump_lists/live_list"
        DUMPCORE_TOP_DIR="$CURRENT_DIR"
    fi
else
    if [[ -f $DUMPLIST_FILE ]]; then
	DUMPLIST_FILE=$(readlink -f $DUMPLIST_FILE)
    else
        echo "Error dumpfile list \"$DUMPLIST_FILE\" not exist!" 1>&2
        exit 1
    fi
fi

if [ ! $COMMAND_FILE == "" ]; then
    if [ -f $COMMAND_FILE ]; then
        COMMAND_FILE=$(readlink -f $COMMAND_FILE)
    else
        echo "Error $COMMAND_FILE not exist!" 1>&2
        exit 1
    fi
fi

if [ ! $COMMANDLIST_FILE == "" ]; then
    if [ -f $COMMANDLIST_FILE ]; then
        COMMANDLIST_FILE=$(readlink -f $COMMANDLIST_FILE)
    else
        echo "Error $COMMANDLIST_FILE not exist!" 1>&2
        exit 1
    fi
fi

if [[ $COMMAND_FILE == "" && $COMMANDLIST_FILE == "" ]]; then
    echo "Error no command list file(-c) nor command file(-b) exist" 1>&2
    print_useage && exit 1
fi

if [[ ! $COMMAND_FILE == "" && ! $COMMANDLIST_FILE == "" ]]; then
    echo "Error command list file(-c) and command file(-b) both exist!" 1>&2
    print_useage && exit 1
fi

if [[ $CRASH == "" || ! -x $CRASH ]]; then
    echo "Error crash path $CRASH not exist or executable!" 1>&2
    exit 1
fi
CRASH=$(readlink -f $CRASH)
[[ $DO_LIVE == "FALSE" && -z $DUMPLIST_FILE ]] && CRASH_ARCH=$(get_crash_arch $CRASH)

if [[ ! $CRASH2 == "" && ! -x $CRASH2 ]]; then
    echo "Error crash2 path $CRASH2 not exist or executable!" 1>&2
    exit 1
fi
if [[ ! $CRASH2 == "" ]]; then
    CRASH2=$(readlink -f $CRASH2)
    [[ $DO_LIVE == "FALSE" && -z $DUMPLIST_FILE ]] && CRASH2_ARCH=$(get_crash_arch $CRASH2)
fi

[[ $DO_LIVE == "FALSE" && -z $DUMPLIST_FILE ]] && {
    [[ ! $CRASH2 == "" && ! $CRASH_ARCH == $CRASH2_ARCH ]] && {
        echo "Arch crash:($CRASH_ARCH) and crash2:($CRASH2_ARCH) are not match!" 1>&2
        exit 1
    }
    DUMPLIST_FILE="$DEFAULT_DUMPLIST_FILE"
    generate_dumplist $DUMPCORE_TOP_DIR $CRASH_ARCH $DUMPLIST_FILE

}

# CONCURRENCY should be 1,2,3...
CONCURRENCY_REGX='^[1-9][0-9]*$'
if [[ ! $CONCURRENCY == "" && ! $CONCURRENCY =~ $CONCURRENCY_REGX ]]; then
    echo "Error: $CONCURRENCY is not valid concurrency!" 1>&2
    exit 1
fi

echo "We are using crash path $CRASH..."
if [[ ! $CRASH2 == "" ]]; then
    echo "We are using crash2 path $CRASH2..."
fi

function check_line_results()
{
    # $1: the string $2: filename
    VAR1="$1"_START_LINE
    VAR2="$1"_END_LINE
    if [[ ${!VAR1} == "1" || ${!VAR2} == "-1" ]]; then
        {
            echo "Error $(readlink -f $2) file format"
            echo
            echo "Example:"
            echo "$1_START"
            echo "your list1"
            echo "your list2"
            echo "..."
            echo "$1_END"
        } 1>&2
        exit 1
    fi
    [[ ${!VAR1} -gt ${!VAR2} ]] && return 1 || return 0
}
export -f check_line_results

# If the following value is 1 or -1, then indicate strings as 
# "DUMPLIST_START" "DUMPLIST_END" not exist, so it's abnormal,
# checked in function check_line_results
function get_linenum_in_file()
{
    # $1: file name, $2: string
    awk -v str="$2" '{if($0==str){print NR}}' $1
}
export -f get_linenum_in_file
###############Done check inputs######################

###############Start check difftools##################
DIFF_TOOLS=("tkdiff" "kdiff3" "meld" "kompare" "colordiff" "wdiff" "diff")
for TOOL in ${DIFF_TOOLS[@]}; do
    DIFF_TOOL=$(which $TOOL 2>/dev/null)
    if [ $? -eq 0 ]; then
        break;
    fi
done

source $CURRENT_DIR/utils/log_filter.sh
function output_final_and_popup_show_diff()
{
    if [[ -f $CRASH_INSTANCE_OUTPUT ]]; then
        mv $CRASH_INSTANCE_OUTPUT $CRASH_FINAL_OUTPUT
        echo "Now filtering $CRASH_FINAL_OUTPUT log, please wait..."
        filter_log_file $CRASH_FINAL_OUTPUT > $CRASH_FINAL_FILTERED_OUTPUT
    fi

    if [[ ! $CRASH2 == "" ]]; then
        if [[ -f $CRASH2_INSTANCE_OUTPUT ]]; then
            mv $CRASH2_INSTANCE_OUTPUT $CRASH2_FINAL_OUTPUT
            mv $CRASH_INSTANCE_OUTPUT_DIFF $CRASH_FINAL_OUTPUT_DIFF
            echo "Now filtering $CRASH2_FINAL_OUTPUT log, please wait..."
            filter_log_file $CRASH2_FINAL_OUTPUT > $CRASH2_FINAL_FILTERED_OUTPUT
        fi
        echo
        echo "---------------------------"
        echo "To view the filtered differences for crash and crash2 output:"
        echo "$CURRENT_DIR/analyze_log_diff.sh -c $CRASH_FINAL_OUTPUT_DIFF"
        echo "To view the complete differences for crash and crash2 output:"
        echo "cat $CRASH_FINAL_OUTPUT_DIFF"
        echo "To regenerate the complete differences:"
        echo "$CURRENT_DIR/analyze_log_diff.sh -a $CRASH_FINAL_OUTPUT -b $CRASH2_FINAL_OUTPUT -c $CRASH_FINAL_OUTPUT_DIFF"
        echo
        echo "All done!"
    else
        echo
        echo "To view logs:"
        echo "zcat $CRASH_FINAL_OUTPUT"
        echo "cat $CRASH_FINAL_FILTERED_OUTPUT"
        echo
        echo "All done!"
    fi
}

function print_message_and_exit()
{
    # $1: exit value
    if [ $1 -eq 0 ]; then
     	exit_progress
        echo "Crash test complete!"
        exit 0
    else
    	exit_progress
        echo "Crash test error occured, please check logs for details" 1>&2
        exit 1
    fi    
}
###############End check difftools####################

if [[ ! "$CONCURRENT_SUBPROCESS" == "TRUE" ]]; then
	init_progress
	export TOTAL_CASES=$(get_dumplist_list_quantity $DUMPLIST_FILE)
	[ $TOTAL_CASES -eq 0 ] && echo \
	    "Empty dumplist! Please check if crash and vmcores are match in arch." && \
	    exit 1
fi
###############Start dealing concurrency##############
function list_process_all_descendants()
{
    # $1: The pid of the process to be listed
    local IMMEDIATE_DESCEND=$(ps -o pid= --ppid "$1")
    for PID in $IMMEDIATE_DESCEND; do
        list_process_all_descendants $PID
    done
    [[ ! "$IMMEDIATE_DESCEND" == "" ]] && echo "$IMMEDIATE_DESCEND"
}

function collect_subprocess_log()
{
    # $1: Prefix of instance output 
    # $2: Subprocess pid
    # $3: Parent process pid
    CHILD_INSTANCE_OUTPUT="$1"."$2"
    PARENT_INSTANCE_OUTPUT="$1"."$3"
    [[ -f $CHILD_INSTANCE_OUTPUT ]] && \
        cat $CHILD_INSTANCE_OUTPUT >> $PARENT_INSTANCE_OUTPUT || \
        echo "Not found $CHILD_INSTANCE_OUTPUT" 1>&2
    rm -f $CHILD_INSTANCE_OUTPUT    
}

if [ ! $CONCURRENCY == "" ]; then
    # Here we will remove -u and -d arguments passed to the script.
    # Remove -u because we want to call the same script without concurrency
    # later.
    # Remove -d because we will generate maximun CONCURRENCY quantity of
    # splitted sub-dumplist files for each subprocess calling. So we will 
    # recreate -d option later.
    SUB_ARGS=`
        echo $ALL_ARGS | \
        sed -E 's/-u\s+[1-9][0-9]*//' | \
        sed -E 's/-d\s+\S+//'`
    declare -a PIDS_ARRAY=( $(for i in {1..$CONCURRENCY}; do echo 0; done) )
    EXIT_VAL_ARRAY=( ${PIDS_ARRAY[@]} )

    # Eg: If we have 10 items on dumplist, and CONCURRENCY is 3, so SPLIT_ARRAY
    # will be (4 3 3), and 3 sub-dumplist files are generated:
    # $SPLIT_OUTPUT_PREFIX.0 (4 items, 1st-4th item of the original dumplist) 
    # $SPLIT_OUTPUT_PREFIX.1 (3 items, 5th-7th item of the original dumplist)
    # $SPLIT_OUTPUT_PREFIX.2 (3 items, 8th-10th item of the original dumplist)
    # Each $SPLIT_OUTPUT_PREFIX.x will be feed to this same script and creating
    # a subprocess, thus we will have 3 concurrent subprocesses dealing with 
    # different items of the original dumplist.
    SPLIT_ARRAY=($($CURRENT_DIR/utils/dumplist_split.sh $DUMPLIST_FILE $CONCURRENCY \
        $SPLIT_OUTPUT_PREFIX))
    if [ $? -ne 0 ]; then
        exit 1
    fi

    # Subprocess creating
    INDEX_ACCUMULATION=0
    # We use CONCURRENT_SUBPROCESS to identify whether we are in
    # subprocesses created here.
    export CONCURRENT_SUBPROCESS=TRUE
    for ((i=0;i<${#SPLIT_ARRAY[@]};i++)); do
        echo "Subprocess $i:" $THIS_FILE "$SUB_ARGS -d $SPLIT_OUTPUT_PREFIX$i"
        export DUMPLIST_INDEX=$INDEX_ACCUMULATION
        $THIS_FILE $SUB_ARGS -d $SPLIT_OUTPUT_PREFIX$i &
        PIDS_ARRAY[$i]=$!
        INDEX_ACCUMULATION=$(($INDEX_ACCUMULATION + ${SPLIT_ARRAY[$i]}))
    done
    unset CONCURRENT_SUBPROCESS

    # Subprocess waiting
    for ((i=0;i<${#SPLIT_ARRAY[@]};i++)); do
        wait -n ${PIDS_ARRAY[$i]}
        EXIT_VAL_ARRAY[$i]=$?
        # Eg: If user set stop on failure and the 2nd item(which belongs to 
        # $SPLIT_OUTPUT_PREFIX.0) of original dumplist fails, thus processes
        # which dealing with $SPLIT_OUTPUT_PREFIX.1/2/3 should be terminated, 
        # no need to wait for them.
        if [[ ${EXIT_VAL_ARRAY[$i]} -ne 0 && $USER_SET_STOP_ON_FAILURE == TRUE ]]; then
            for ((j=$i+1;j<${#SPLIT_ARRAY[@]};j++)); do
                kill -SIGTERM $(list_process_all_descendants ${PIDS_ARRAY[$j]}) \
                    2>/dev/null
            done
        fi
    done

    # Collecting logs of subprocesses
    for ((i=0;i<${#SPLIT_ARRAY[@]};i++)); do
        # Eg: From /tmp/.crash.log.$$ to /tmp/.crash.log
        PREFIX=$(echo $CRASH_INSTANCE_OUTPUT | rev | cut -d'.' -f2- | rev)
        collect_subprocess_log $PREFIX ${PIDS_ARRAY[$i]} $$
        if [[ ! $CRASH2 == "" ]]; then
            PREFIX=$(echo $CRASH2_INSTANCE_OUTPUT | rev | cut -d'.' -f2- | rev)
            collect_subprocess_log $PREFIX ${PIDS_ARRAY[$i]} $$
	    PREFIX=$(echo $CRASH_INSTANCE_OUTPUT_DIFF | rev | cut -d'.' -f2- | rev)
	    collect_subprocess_log $PREFIX ${PIDS_ARRAY[$i]} $$
        fi
        if [[ $USER_SET_STOP_ON_FAILURE == TRUE && ${EXIT_VAL_ARRAY[$i]} -ne 0 ]]; then
            break
        fi
    done

    output_final_and_popup_show_diff
    # If EXIT_VAL_ARRAY contains numbers other than 0, then fails.
    print_message_and_exit $([[ ${EXIT_VAL_ARRAY[@]} =~ [1-9]+ ]] && echo 1 || echo 0)
fi
###############Done dealing concurrency###############

###############Start check crashrc####################
function check_crashrc()
{
    # $1: The folder of crashrc
    { 
        if [ -f $1/.crashrc ]; then
            if [ $1 == "$HOME" ]; then
                echo "WARNING: $1/.crashrc:"
            else
                echo "WARNING: ./crashrc:"
            fi
            cat $1/.crashrc
            echo
            echo -n "enter <RETURN> to continue: "
            read INPUT
        fi 
    } 1>&2
}

CRASHRC_FOLDERS=("$HOME" "$CURRENT_DIR")
for FOLDER in ${CRASHRC_FOLDERS[@]}; do
    check_crashrc $FOLDER
done
###############End check crashrc######################
rm -f $CRASH_INSTANCE_OUTPUT \
    $CRASH2_INSTANCE_OUTPUT

###############Start merge commands###################
function output_each_command_file()
{
    # $1: command file $2: output to file
    COMMAND_START_LINE=$(get_linenum_in_file $1 "COMMAND_START")
    COMMAND_START_LINE=$(($COMMAND_START_LINE + 1))
    COMMAND_END_LINE=$(get_linenum_in_file $1 "COMMAND_END")
    COMMAND_END_LINE=$(($COMMAND_END_LINE - 1))
    check_line_results "COMMAND" $1

    # Since each command file start with COMMAND_START
    # and end with exit/q and COMMAND_END. To combine different
    # command files together, we need to remove each file's COMMAND_* and exit/q,
    # which will be created elsewhere. Then we add 
    # "echo [Command $commandfile: $command]" before each command line, 
    # to output the command we are currently processing.
    #
    # As for complex commands like the ones in command/vtop_ptov_validation,
    # we won't print it out.
    cat $1 | \
        sed -n -e "$COMMAND_START_LINE,"$COMMAND_END_LINE"p" | \
        sed '/^\s*\(exit\|q\)\s*$/d' | \
        sed '/^\s*$/d' | \
        egrep -v "COMMAND_END" | \
        awk -v FNAME="$1" '{if ($0 != "COMMAND_START" && $0 !~ /^\s*#.*/)
            {if($0 ~ /^\s*@.*/){print $0}
            else{printf("echo \"[Command %s: %s]\"\n%s\n",FNAME,$0,$0)}}}' \
        >> $2
}

rm -f $MERGED_COMMANDS
echo "COMMAND_START" > $MERGED_COMMANDS
if [[ ! $COMMANDLIST_FILE == "" ]]; then
    # it's command list file
    COMMANDLIST_START_LINE=$(get_linenum_in_file $COMMANDLIST_FILE "COMMANDLIST_START")
    COMMANDLIST_START_LINE=$(($COMMANDLIST_START_LINE + 1))
    COMMANDLIST_END_LINE=$(get_linenum_in_file $COMMANDLIST_FILE "COMMANDLIST_END")
    COMMANDLIST_END_LINE=$(($COMMANDLIST_END_LINE - 1))
    check_line_results "COMMANDLIST" $COMMANDLIST_FILE

    cd $COMMANDS_TOP_DIR
    while read ARG1 EXTRA_ARGS
    do
        # comment or empty lines
        if [[ $ARG1 == "#"* || $ARG1 == "" ]]; then
            continue
        fi
        # check file exist
        if [ ! -f $ARG1 ]; then
            echo "Error: command file $COMMANDS_TOP_DIR/$ARG1 not found!" 1>&2
            exit 1
        fi
        output_each_command_file $(readlink -f $ARG1) $MERGED_COMMANDS
    done <<< $(cat $COMMANDLIST_FILE | sed -n -e "$COMMANDLIST_START_LINE,"$COMMANDLIST_END_LINE"p")
    cd ~-
else
    # it's command file
    cd $COMMANDS_TOP_DIR
    output_each_command_file $COMMAND_FILE $MERGED_COMMANDS
    cd ~-
fi
echo "q" >> $MERGED_COMMANDS
echo "COMMAND_END" >> $MERGED_COMMANDS

COMMAND_START_LINE=$(get_linenum_in_file $MERGED_COMMANDS "COMMAND_START")
COMMAND_START_LINE=$(($COMMAND_START_LINE + 1))
COMMAND_END_LINE=$(get_linenum_in_file $MERGED_COMMANDS "COMMAND_END")
COMMAND_END_LINE=$(($COMMAND_END_LINE - 1))
check_line_results "COMMAND" $MERGED_COMMANDS
###############End merge commands#####################

###############Start loop preparation#################
function invoke_crash()
{
    # $1:crash path, $2:junk output log path
    TEST_TITLE="[Test $DUMPLIST_INDEX]\n"
    if [ $ARG1 == "live" ]; then
        TEST_TITLE=$TEST_TITLE"[Dumpfile $ARG1]\n"
        SUDO="sudo -E"
        ARG1=""
        LIVE_FLAG="yes"
    else
        TEST_TITLE=$TEST_TITLE"[Dumpfile $ARG1 $ARG2]\n"
        LIVE_FLAG="no"
    fi

    CRASH_CMD="$SUDO $1 $OPTARGS $ARG1 $ARG2 $EXTRA_ARGS"
    TEST_TITLE=$TEST_TITLE$CRASH_CMD
    echo -e $TEST_TITLE | tee >(gzip --stdout > $2)

    cat $MERGED_COMMANDS | \
        sed -n -e "$COMMAND_START_LINE,"$COMMAND_END_LINE"p" | 
        eval $CRASH_CMD 2>&1 | \
        # awk "$TIME_COMMAND" | \
        tee >(gzip --stdout >> $2) | \
        live_test_filter $LIVE_FLAG | log_filter $(arch) | uniq
    # We want to log and return crash exit code.
    # MUST change with the previous command accordingly.
    EXIT_VAL=${PIPESTATUS[2]}
    echo -e "Crash returned with $EXIT_VAL\n" | tee >(gzip --stdout >> $2)
    increase_progress
    return $EXIT_VAL
}

function check_should_stop()
{
    if [ "$USER_SET_STOP_ON_FAILURE" = "TRUE" ] && [ "$DO_NOT_STOP_ON_FAILURE" = "FALSE" ]; then
        return 1
    else
        return 0
    fi
}

cd $DUMPCORE_TOP_DIR
###############End loop preparation###################

###############The loop ##############################
DUMPLIST_START_LINE=$(get_linenum_in_file $DUMPLIST_FILE "DUMPLIST_START")
DUMPLIST_START_LINE=$(($DUMPLIST_START_LINE + 1))
DUMPLIST_END_LINE=$(get_linenum_in_file $DUMPLIST_FILE "DUMPLIST_END")
DUMPLIST_END_LINE=$(($DUMPLIST_END_LINE - 1))
check_line_results "DUMPLIST" $DUMPLIST_FILE

DO_NOT_STOP_ON_FAILURE=FALSE
while read ARG1 ARG2 EXTRA_ARGS
do
    FAILURE_FLAG=FALSE

    # comment or empty lines
    if [[ $ARG1 == "#"* || $ARG1 == "" ]]; then
        continue
    fi

    if [[ $ARG1 == "DO_NOT_STOP_ON_FAILURE" ]]; then
        DO_NOT_STOP_ON_FAILURE=TRUE
        continue
    fi

    DUMPLIST_INDEX=$(($DUMPLIST_INDEX + 1))
    if [[ $ARG1 == "live" && $DO_LIVE == FALSE ]]; then
        echo "WARNING: Skip live test, maybe (-a) not on?"
        continue
    fi

    if [[ $CRASH2 == "" ]]; then
        invoke_crash $CRASH $CRASH_INSTANCE_JUNK_OUTPUT | format_output_for_each_crash_invoke | \
            output_progress $TOTAL_CASES &
        PID=$!
        wait -n $PID
        EXIT_VAL=$?
        if [ $EXIT_VAL -ne 0 ]; then
            FAILURE_FLAG=TRUE
        fi
        if [[ $VERBOSE_MODE == TRUE || $FAILURE_FLAG == TRUE ]]; then
            cat $CRASH_INSTANCE_JUNK_OUTPUT >> $CRASH_INSTANCE_OUTPUT
        fi
    else
        # Here we compare the outputs of CRASH and CRASH2 are same or not.
        # By put crash and crash2 into background will shorten the overall time.
        invoke_crash $CRASH $CRASH_INSTANCE_JUNK_OUTPUT > /dev/null &
        PID[0]=$!
        invoke_crash $CRASH2 $CRASH2_INSTANCE_JUNK_OUTPUT > /dev/null &
        PID[1]=$!
        for ((i=0;i<2;i++)); do
            wait -n ${PID[$i]}
            EXIT_VAL[$i]=$?
        done
        # 1st check: the return value diff
        if [ ! "${EXIT_VAL[0]}" == "${EXIT_VAL[1]}" ]; then
            echo "Exit values mismatch, got (CRASH-CRASH2): (${EXIT_VAL[0]}-${EXIT_VAL[1]})!" | \
                tee >(gzip --stdout >> $CRASH_INSTANCE_JUNK_OUTPUT) | \
                tee >(gzip --stdout >> $CRASH2_INSTANCE_JUNK_OUTPUT) > /dev/null
            FAILURE_FLAG=TRUE
        fi
        # 2nd check: the return value == 0
        if [[ ! ${EXIT_VAL[0]} == 0 || ! ${EXIT_VAL[1]} == 0 ]]; then
            echo "Exit values are not 0, got (CRASH-CRASH2): (${EXIT_VAL[0]}-${EXIT_VAL[1]})!" | \
                tee >(gzip --stdout >> $CRASH_INSTANCE_JUNK_OUTPUT) | \
                tee >(gzip --stdout >> $CRASH2_INSTANCE_JUNK_OUTPUT) > /dev/null
            FAILURE_FLAG=TRUE
        fi
        # 3rd check: the output junk
        $CURRENT_DIR/analyze_log_diff.sh -a $CRASH_INSTANCE_JUNK_OUTPUT \
	    -b $CRASH2_INSTANCE_JUNK_OUTPUT \
            -c $CRASH_INSTANCE_JUNK_OUTPUT_DIFF | \
	    output_progress $(($TOTAL_CASES + $TOTAL_CASES))
	echo "" >> $CRASH_INSTANCE_OUTPUT_DIFF
	cat $CRASH_INSTANCE_JUNK_OUTPUT_DIFF >> $CRASH_INSTANCE_OUTPUT_DIFF

        # If we are in debug mode or failure occured, persist the output log
        if [[ $VERBOSE_MODE == TRUE || $FAILURE_FLAG == TRUE ]]; then
            cat $CRASH_INSTANCE_JUNK_OUTPUT >> $CRASH_INSTANCE_OUTPUT
            cat $CRASH2_INSTANCE_JUNK_OUTPUT >> $CRASH2_INSTANCE_OUTPUT
        fi
    fi
    
    if [[ $FAILURE_FLAG == TRUE ]]; then
        check_should_stop
        EXIT_VAL=$?
        [ $EXIT_VAL -ne 0 ] && break
    fi

    DO_NOT_STOP_ON_FAILURE=FALSE
done <<< $(cat $DUMPLIST_FILE | sed -n -e "$DUMPLIST_START_LINE,"$DUMPLIST_END_LINE"p")

###############The loop end###########################

cd ~-
if [[ $CONCURRENT_SUBPROCESS == "TRUE" ]]; then
    # We are subprocess, just exit with status.
    exit $EXIT_VAL
else
    output_final_and_popup_show_diff
    print_message_and_exit $EXIT_VAL
fi