#!/bin/bash

CURRENT_DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd -P)
FILE_NAME=$(basename ${BASH_SOURCE[0]})
THIS_FILE=$CURRENT_DIR/$FILE_NAME

# Persistent output for recording the all output log of CRASH.
# Junk output for recording the specific output of 
# a specific combination of CRASH command list and vmcore dump.  
CRASH_PERSISTENT_OUTPUT="/tmp/crash.log"
CRASH_JUNK_OUTPUT="/tmp/.crash_junk.log"
CRASH2_PERSISTENT_OUTPUT="/tmp/crash2.log"
CRASH2_JUNK_OUTPUT="/tmp/.crash2_junk.log"
MERGED_COMMANDS="/tmp/.merged_commands.log"
DUMPLIST_INDEX=0
COMMANDLIST_INDEX=0
VERBOSE_MODE=FALSE
DIFF_TOOL=""

CRASH=$(which crash)
DUMPLIST_FILE=""
DUMPCORE_TOP_DIR=""
COMMANDLIST_FILE=""
COMMAND_FILE=""
COMMANDS_TOP_DIR=$CURRENT_DIR
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
    echo "-f [FILE]    Specify crash"
    echo "-D [DIR]     Specify top dir of vmcore(must)"
    echo "-d [FILE]    Specify dumpcore list file(must)"
    echo "-C [DIR]     Specify top dir of commands, default to current dir"
    echo "-c [FILE]    Specify crash commands list file"
    echo "-b [FILE]    Specify crash commands file"
    echo "                  One of -c and -b is a (must)"
    echo "-a           (Not inplemented)Alive test"
    echo "-l           (Not inplemented)Local test"
    echo "-v           (Not inplemented)Need verify the existance of each dumpcore item"
    echo "-t           Time each test"
    echo "-s           Stop on failure"
    echo "-m           More verbose log output"
    echo "-e [FILE]    Specify extra crash for behaviour comparison"
}
export -f print_useage

while getopts "f:d:D:C:c:b:alvtsme:" OPT; do
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
        m) VERBOSE_MODE=TRUE
            ;;
        e) CRASH2="$OPTARG"
            ;;
        *) print_useage && exit 1
            ;;
    esac
done

trap "echo 'The program is terminated by user.' && exit 0" SIGTERM SIGINT

###############Start check inputs####################
if [[ $DUMPCORE_TOP_DIR == "" ]]; then
    print_useage && exit 1
fi

if [[ $DUMPLIST_FILE == "" || ! -f $DUMPLIST_FILE ]]; then
    echo "Error dumpfile list not exist!" 1>&2
    exit 1
fi
DUMPLIST_FILE=$(readlink -f $DUMPLIST_FILE)

if [[ ! $COMMAND_FILE == "" && -f $COMMAND_FILE ]]; then
    COMMAND_FILE=$(readlink -f $COMMAND_FILE)
fi

if [[ ! $COMMANDLIST_FILE == "" && -f $COMMANDLIST_FILE ]]; then
    COMMANDLIST_FILE=$(readlink -f $COMMANDLIST_FILE)
fi

if [[ $COMMAND_FILE == "" && $COMMANDLIST_FILE == "" ]]; then
    echo "Error no command list file(-c) nor command file(-b) exist" 1>&2
    print_useage && exit 1
fi

if [[ ! $COMMAND_FILE == "" && ! $COMMANDLIST_FILE == "" ]]; then
    echo "Error command list file(-c) and command file(-b) both exist!" 1>&2
    print_useage && exit 1
fi

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

function check_line_results()
{
    # $1: the string $2: filename
    VAR1="$1"_START_LINE
    VAR2="$1"_END_LINE
    if [[ ${!VAR1} == "1" || ${!VAR2} == "-1" ]]; then
        echo "Error $(readlink -f $2) file format" 1>&2
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

###############Start check difftools##################
DIFF_TOOLS=("tkdiff" "kdiff3" "meld" "kompare" "colordiff" "wdiff" "diff")
for TOOL in ${DIFF_TOOLS[@]}; do
    DIFF_TOOL=$(which $TOOL 2>/dev/null)
    if [ $? -eq 0 ]; then
        break;
    fi
done
###############End check difftools####################

###############Start merge commands###################
if [[ ! $COMMANDLIST_FILE == "" ]]; then
    # it's command list file
    COMMANDLIST_START_LINE=$(get_linenum_in_file $COMMANDLIST_FILE "COMMANDLIST_START")
    COMMANDLIST_START_LINE=$(($COMMANDLIST_START_LINE + 1))
    COMMANDLIST_END_LINE=$(get_linenum_in_file $COMMANDLIST_FILE "COMMANDLIST_END")
    COMMANDLIST_END_LINE=$(($COMMANDLIST_END_LINE - 1))
    check_line_results "COMMANDLIST" $COMMANDLIST_FILE

    rm -f $MERGED_COMMANDS
    cd $COMMANDS_TOP_DIR
    echo "COMMAND_START" > $MERGED_COMMANDS
    cat $COMMANDLIST_FILE | sed -n -e "$COMMANDLIST_START_LINE,"$COMMANDLIST_END_LINE"p" | \
        while read ARG1 EXTRA_ARGS
    do
        # comment or empty lines
        if [[ $ARG1 == "#"* || $ARG1 == "" ]]; then
            continue
        fi
        # check file exist
        if [ ! -f $ARG1 ]; then
            echo "Error: command file $COMMANDS_TOP_DIR/$ARG1 not found!" 1>&2
            if [ "$USER_SET_STOP_ON_FAILURE" = "TRUE" ]; then
                exit 1
            else
                echo "Stop on failure not set, continuing..." 1>&2
                continue
            fi
        fi

        cat $ARG1 | \
            egrep -v "COMMAND_(START|END)" | \
            sed '/^\s*\(exit\|q\)\s*$/d' \
            >> $MERGED_COMMANDS
    done
    echo "q" >> $MERGED_COMMANDS
    echo "COMMAND_END" >> $MERGED_COMMANDS
    cd ~-
else
    # it's command file
    MERGED_COMMANDS=$COMMAND_FILE
fi
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
    echo "[Test $DUMPLIST_INDEX]" > $2
    echo $SUDO $TIME_COMMAND $1 $OPTARGS $ARG1 $ARG2 $EXTRA_ARGS | \
        tee -a $2
    cat $MERGED_COMMANDS | \
        sed -n -e "$COMMAND_START_LINE,"$COMMAND_END_LINE"p" | \
        $SUDO $TIME_COMMAND $1 $OPTARGS $ARG1 $ARG2 $EXTRA_ARGS | \
        tee -a $2
    # We want to log and return crash exit code
    EXIT_VAL=${PIPESTATUS[2]}
    echo "Crash returnd with $EXIT_VAL" | tee -a $2
    return $EXIT_VAL
}
export -f invoke_crash

function check_should_stop()
{
    if [ "$USER_SET_STOP_ON_FAILURE" = "TRUE" ] && [ "$DO_NOT_STOP_ON_FAILURE" = "FALSE" ]; then
        exit 1
    fi
}

rm -f $CRASH_PERSISTENT_OUTPUT \
    $CRASH2_PERSISTENT_OUTPUT
cd $DUMPCORE_TOP_DIR
###############End loop preparation###################

###############The loop ##############################
DUMPLIST_START_LINE=$(get_linenum_in_file $DUMPLIST_FILE "DUMPLIST_START")
DUMPLIST_START_LINE=$(($DUMPLIST_START_LINE + 1))
DUMPLIST_END_LINE=$(get_linenum_in_file $DUMPLIST_FILE "DUMPLIST_END")
DUMPLIST_END_LINE=$(($DUMPLIST_END_LINE - 1))
check_line_results "DUMPLIST" $DUMPLIST_FILE

cat $DUMPLIST_FILE | sed -n -e "$DUMPLIST_START_LINE,"$DUMPLIST_END_LINE"p" | \
    while read ARG1 ARG2 EXTRA_ARGS
do
    FAILURE_FLAG=FALSE
    DO_NOT_STOP_ON_FAILURE=FALSE
    DUMPLIST_INDEX=$(($DUMPLIST_INDEX + 1))

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

    echo "[Test $DUMPLIST_INDEX]"
    if [[ $CRASH2 == "" ]]; then
        invoke_crash $CRASH $CRASH_JUNK_OUTPUT
        EXIT_VAL=$?
        if [ $EXIT_VAL -ne 0 ]; then
            FAILURE_FLAG=TRUE
        fi
        if [[ $VERBOSE_MODE == TRUE || $FAILURE_FLAG == TRUE ]]; then
            cat $CRASH_JUNK_OUTPUT >> $CRASH_PERSISTENT_OUTPUT
        fi
    else
        # Here we compare the outputs of CRASH and CRASH2 are same or not.
        invoke_crash $CRASH $CRASH_JUNK_OUTPUT
        EXIT_VAL=$?
        invoke_crash $CRASH2 $CRASH2_JUNK_OUTPUT
        EXIT_VAL2=$?

        # 1st check: the return value diff
        if [ ! "$EXIT_VAL" == "$EXIT_VAL2" ]; then
            echo "Exit values mismatch, got (CRASH-CRASH2): ($EXIT_VAL-$EXIT_VAL2)!" | \
                tee -a $CRASH_JUNK_OUTPUT | \
                tee -a $CRASH2_JUNK_OUTPUT
            FAILURE_FLAG=TRUE
        fi
        # 2nd check: the return value == 0
        if [[ ! $EXIT_VAL == 0 || ! $EXIT_VAL2 == 0 ]]; then
            echo "Exit values are not 0, got (CRASH-CRASH2): ($EXIT_VAL-$EXIT_VAL2)!" | \
                tee -a $CRASH_JUNK_OUTPUT | \
                tee -a $CRASH2_JUNK_OUTPUT
            FAILURE_FLAG=TRUE
        fi
        # 3rd check: the output junk
        if [ ! "$(sum $CRASH_JUNK_OUTPUT)" == "$(sum $CRASH2_JUNK_OUTPUT)" ]; then
            echo "Crash output mismatch, check diff in $CRASH_PERSISTENT_OUTPUT and $CRASH2_PERSISTENT_OUTPUT" 1>&2
            FAILURE_FLAG=TRUE
        fi
        # If we are in debug mode or failure occured, persist the output log
        if [[ $VERBOSE_MODE == TRUE || $FAILURE_FLAG == TRUE ]]; then
            cat $CRASH_JUNK_OUTPUT >> $CRASH_PERSISTENT_OUTPUT
            cat $CRASH2_JUNK_OUTPUT >> $CRASH2_PERSISTENT_OUTPUT
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
    if [[ ! $CRASH2 == "" && -f $CRASH2_PERSISTENT_OUTPUT ]]; then
        if [ ! DIFF_TOOL == "" ]; then
            echo "Now invoke $DIFF_TOOL to present diff..."
            $DIFF_TOOL $CRASH_PERSISTENT_OUTPUT $CRASH2_PERSISTENT_OUTPUT
        else
            echo "No diff tools found, please install one of \"${DIFF_TOOLS[@]}\"" 1>&2
        fi
    fi
}
export -f popup_show_diff

cd ~-
popup_show_diff
if [ $EXIT_VAL -eq 0 ]; then
    echo "Crash test complete!"
    exit 0
else
    echo "Crash test error occured, please check logs for details" 1>&2
    exit 1
fi