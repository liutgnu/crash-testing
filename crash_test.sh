#!/bin/bash

CURRENT_DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd -P)
FILE_NAME=$(basename ${BASH_SOURCE[0]})
THIS_FILE=$CURRENT_DIR/$FILE_NAME

# Persistent output for recording the all output log of CRASH.
# Junk output for recording the specific output of 
# a specific combination of CRASH command list and vmcore dump.  
CRASH_PERSISTENT_OUTPUT="/tmp/crash.log"
CRASH_JUNK_OUTPUT="/tmp/crash_junk.log"
CRASH2_PERSISTENT_OUTPUT="/tmp/crash2.log"
CRASH2_JUNK_OUTPUT="/tmp/crash2_junk.log"
SUMMARY_OUTPUT="/tmp/crash_summary.log"
DUMP_FOLDER=""

CRASH=$(which crash)
DUMPLIST_FILE=""
COMMANDS_FILE=""
DO_LIVE=FALSE
DO_LOCAL=FALSE
VERIFY=FALSE
TIME_COMMAND=""
CRASH2=""
SUDO=""
OPTARGS="-s"
USER_SET_STOP_ON_FAILURE=FALSE

function print_useage()
{
    echo "Useage: $FILE_NAME [OPTS]..."
    echo
    echo "-c [FILE]    Specify crash"
    echo "-d [DIR]     Specify top dir of vmcore(must)"
    echo "-D [FILE]    Specify dumpcore list file"
    echo "-C [FILE]    Specify crash commands list file"
    echo "-a           (Not inplemented)Alive test"
    echo "-l           (Not inplemented)Local test"
    echo "-v           (Not inplemented)Need verify the existance of each dumpcore item"
    echo "-t           Time each test"
    echo "-s           Stop on failure"
    echo "-e [FILE]    Specify another crash for behaviour comparison"
}
export -f print_useage

while getopts "c:d:D:C:lavtse:" OPT; do
    case $OPT in
        c) CRASH="$OPTARG"
            ;;
        D) DUMPLIST_FILE="$OPTARG"
            ;;
        d) DUMP_FOLDER="$OPTARG"
            ;;
        C) COMMANDS_FILE="$OPTARG"
            ;;
        a) DO_LIVE=TRUE
            SUDO="sudo"
	        ;;
        l) DO_LOCAL=TRUE
	        ;;
	    v) VERIFY=TRUE
	        ;;
        t) TIME_COMMAND="time -p"
            ;;
        s) USER_SET_STOP_ON_FAILURE=TRUE
            ;;
        e) CRASH2="$OPTARG"
            ;;
        *) print_useage && exit 1
            ;;
    esac
done

trap "echo 'The program is terminated by user.' && exit 0" SIGTERM SIGINT

###############Start check inputs####################
if [[ $DUMP_FOLDER == "" ]]; then
    print_useage && exit 1
fi

if [[ $DUMPLIST_FILE == "" || ! -f $DUMPLIST_FILE ]]; then
    echo "Error dumpfile list not exist!" 1>&2
    exit 1
fi
DUMPLIST_FILE=$(readlink -f $DUMPLIST_FILE)

if [[ $COMMANDS_FILE == "" || ! -f $COMMANDS_FILE ]]; then
    echo "Error commands list not exist!" 1>&2
    exit 1
fi
COMMANDS_FILE=$(readlink -f $COMMANDS_FILE)

if [ ! -x $CRASH ]; then
    echo "Error crash path $CRASH not exist or executable!" 1>&2
    exit 1
fi

if [[ ! $CRASH2 == "" && ! -x $CRASH2 ]]; then
    echo "Error crash2 path $CRASH2 not exist or executable!" 1>&2
    exit 1
fi

echo "We are using crash path $CRASH..."
if [[ ! $CRASH2 == "" ]]; then
    echo "We are using crash2 path $CRASH2..."
fi

function check_list_file_format()
{
    # $1: DUMPLIST or COMMANDS
    VAR1="$1"_START_LINE
    VAR2="$1"_END_LINE
    FILE="$1"_FILE
    if [[ ${!VAR1} == "1" || ${!VAR2} == "-1" ]]; then
        echo "Error $(readlink -f ${!FILE}) file format" 1>&2
        echo 1>&2
        echo "Example:" 1>&2
        echo "$1_START" 1>&2
        echo "your list1" 1>&2
        echo "your list2" 1>&2
        echo "..." 1>&2
        echo "$1_END" 1>&2
        exit 1
    fi
}
export -f check_list_file_format

# If the following value is 1 or -1, then indicate strings as 
# "DUMPLIST_START" "DUMPLIST_END" not exist, so it's error format,
# checked in function check_list_file_format
DUMPLIST_START_LINE=`awk -v str="DUMPLIST_START" '{if($0==str){print NR}}' $DUMPLIST_FILE`
DUMPLIST_START_LINE=$(($DUMPLIST_START_LINE + 1))
DUMPLIST_END_LINE=`awk -v str="DUMPLIST_END" '{if($0==str){print NR}}' $DUMPLIST_FILE`
DUMPLIST_END_LINE=$(($DUMPLIST_END_LINE - 1))
COMMANDS_START_LINE=`awk -v str="COMMANDS_START" '{if($0==str){print NR}}' $COMMANDS_FILE`
COMMANDS_START_LINE=$(($COMMANDS_START_LINE + 1))
COMMANDS_END_LINE=`awk -v str="COMMANDS_END" '{if($0==str){print NR}}' $COMMANDS_FILE`
COMMANDS_END_LINE=$(($COMMANDS_END_LINE - 1))

check_list_file_format "DUMPLIST"
check_list_file_format "COMMANDS"
###############Done check inputs#####################

###############Start check crashrc####################
function check_crashrc()
{
    # $1: The folder of crashrc
    if [ -f $1/.crashrc ]; then
        if [ $1 == "$HOME" ]; then
            echo "WARNING: $1/.crashrc:" 1>&2
        else
            echo "WARNING: ./crashrc:" 1>&2
        fi
        cat $1/.crashrc 1>&2
        echo 1>&2
        echo -n "enter <RETURN> to continue: " 1>&2
        read INPUT
    fi
}
export -f check_crashrc

CRASHRC_FOLDERS=("$HOME" "$CURRENT_DIR")
for FOLDER in ${CRASHRC_FOLDERS[@]}; do
    check_crashrc $FOLDER
done
###############End check crashrc######################

###############Start loop preparation#################
function invoke_crash()
{
    # $1:crash path, $2:persistent output log path, $3:junk output log path
    echo $SUDO $TIME_COMMAND $1 $OPTARGS $ARG1 $ARG2 $EXTRA_ARGS | \
        tee -a $2
    cat $COMMANDS_FILE | \
        sed -n -e "$COMMANDS_START_LINE,"$COMMANDS_END_LINE"p" | \
        $SUDO $TIME_COMMAND $1 $OPTARGS $ARG1 $ARG2 $EXTRA_ARGS | \
        tee -a $2 | \
        tee $3
    # We want return crash exit code
    return ${PIPESTATUS[2]}
}
export -f invoke_crash

function check_should_stop()
{
    if [ "$USER_SET_STOP_ON_FAILURE" = "TRUE" ] && [ "$DO_NOT_STOP_ON_FAILURE" = "FALSE" ]; then \
        exit 1
    fi
}

rm -f $CRASH_PERSISTENT_OUTPUT \
    $CRASH2_PERSISTENT_OUTPUT \
    $SUMMARY_OUTPUT
cd $DUMP_FOLDER
###############End loop preparation###################

###############The loop ##############################
cat $DUMPLIST_FILE | sed -n -e "$DUMPLIST_START_LINE,"$DUMPLIST_END_LINE"p" | \
    while read ARG1 ARG2 EXTRA_ARGS
do
    FAILURE_FLAG=FALSE
    DO_NOT_STOP_ON_FAILURE=FALSE

    # comment or empty lines
    if [[ $ARG1 == "#"* || $ARG1 == "" ]]; then
        continue
    fi

    if [[ $ARG1 == "DO_NOT_STOP_ON_FAILURE" ]]; then
        DO_NOT_STOP_ON_FAILURE=TRUE
        continue
    fi

    if [[ $ARG1 == "LIVE" ]]; then
        SUDO="sudo"
        continue
    fi

    invoke_crash $CRASH $CRASH_PERSISTENT_OUTPUT $CRASH_JUNK_OUTPUT
    EXIT_VAL=$?
    if [ $EXIT_VAL -ne 0 ]; then
        FAILURE_FLAG=TRUE
    fi

    # Here we compare the outputs of CRASH and CRASH2 are same or not.
    if [[ ! $CRASH2 == "" ]]; then
        invoke_crash $CRASH2 $CRASH2_PERSISTENT_OUTPUT $CRASH2_JUNK_OUTPUT
        EXIT_VAL2=$?

        # 1st check: the return value
        if [ ! "$EXIT_VAL" == "$EXIT_VAL2" ]; then
            echo "Exit value mismatch, got $EXIT_VAL <-> $EXIT_VAL2 !" | \
                tee -a $SUMMARY_OUTPUT
            FAILURE_FLAG=TRUE
        fi
        # 2nd check: the output junk
        if [ ! "$(sum $CRASH_JUNK_OUTPUT)" == "$(sum $CRASH2_JUNK_OUTPUT)" ]; then
            echo "Crash output mismatch, check diff in $CRASH_PERSISTENT_OUTPUT and $CRASH2_PERSISTENT_OUTPUT" | \
                tee -a $SUMMARY_OUTPUT
            FAILURE_FLAG=TRUE
        fi
    fi
    
    if [[ $FAILURE_FLAG == TRUE ]]; then
        check_should_stop
    fi
done
EXIT_VAL=$?
###############The loop end###########################

function popup_show_diff()
{
    if [[ ! $CRASH2 == "" ]]; then
        echo "We use tkdiff to view log diff..."
        tkdiff $CRASH_PERSISTENT_OUTPUT $CRASH2_PERSISTENT_OUTPUT
    fi
}
export -f popup_show_diff

cd ~-
if [ $EXIT_VAL -eq 0 ]; then
    echo "Crash test complete!"
    popup_show_diff
    exit 0
else
    echo "Crash test error occured, please check logs for details" 1>&2
    popup_show_diff
    exit 1
fi