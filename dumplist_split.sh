#!/bin/bash
# This file is part of crash_test.sh, DON'T call it manually.
# This file is used to split vmcore dump list(specified by -d in crash_test.sh) 
# into N sub-lists, where N is given by concurrency(specified by -u in 
# crash_test.sh)
#
# Inputs: 
# $1: the dumplist_file
# $2: concurrency
# $3: prefix of splitted output filename

CURRENT_DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd -P)
FILE_NAME=$(basename ${BASH_SOURCE[0]})
THIS_FILE=$CURRENT_DIR/$FILE_NAME
SPLIT_OUTPUT_PREFIX=$3

# Check whether we are in the context of crash_test.sh.
EXPORTED_FUNCS_ARRAY=( $(declare -Fx | awk '{print $3}') )
function check_func_exported()
{
    # $1: The checked func
    for FUNC in ${EXPORTED_FUNCS_ARRAY[@]}; do
        if [[ "$FUNC" == "$1" ]]; then
            return 0
        fi
    done
    return 1
}
check_func_exported "get_linenum_in_file"
EXIT_VAL1=$?
check_func_exported "check_line_results"
EXIT_VAL2=$?
if [[ ! $EXIT_VAL1 == 0 || ! $EXIT_VAL2 == 0 ]]; then
    echo "$FILE_NAME should be called in crash_test.sh!" 1>&2
    exit 1
fi
# Done check

DUMPLIST_FILE=$(readlink -f $1)

DUMPLIST_START_LINE=$(get_linenum_in_file $DUMPLIST_FILE "DUMPLIST_START")
DUMPLIST_START_LINE=$(($DUMPLIST_START_LINE + 1))
DUMPLIST_END_LINE=$(get_linenum_in_file $DUMPLIST_FILE "DUMPLIST_END")
DUMPLIST_END_LINE=$(($DUMPLIST_END_LINE - 1))
check_line_results "DUMPLIST" $DUMPLIST_FILE

# Temporary array for split accumulation
declare -a ACCUMU_ARRAY=( $(for i in {1..$2}; do echo 0; done) )
COUNT=0

# Calculating the split result, which will be stored in ACCUMU_ARRAY.
# Each iteration will echo the array, thus the last echo is the final result.
SPLIT_RESULT_ARRAY=(`
cat $DUMPLIST_FILE | sed -n -e "$DUMPLIST_START_LINE,"$DUMPLIST_END_LINE"p" | \
    while read -r LINE; do

    # comment or empty lines
    if [[ $LINE == "#"* || $LINE == "" ]]; then
        continue
    fi

    # action control lines
    if [[ $LINE == *"DO_NOT_STOP_ON_FAILURE"* ]]; then
        continue
    fi

    ACCUMU_ARRAY[$(($COUNT % $2))]=$((${ACCUMU_ARRAY[$(($COUNT % $2))]} + 1))
    COUNT=$(($COUNT + 1))
    echo ${ACCUMU_ARRAY[@]}
done | tail -n 1`)

# In case we get an empty dump list
if [ "$SPLIT_RESULT_ARRAY" == "" ]; then
    SPLIT_RESULT_ARRAY=(0)
fi

# Output the split result array to crash_test.sh
echo ${SPLIT_RESULT_ARRAY[@]}

COUNT=0
ARRAY_INDEX=0
rm -f $SPLIT_OUTPUT_PREFIX*

# Now work on splitting the dump list file into sub-files as SPLIT_RESULT_ARRAY
# wants
cat $DUMPLIST_FILE | sed -n -e "$DUMPLIST_START_LINE,"$DUMPLIST_END_LINE"p" | \
    while read -r LINE \
        && { [ "$COUNT" == "${SPLIT_RESULT_ARRAY[$ARRAY_INDEX]}" ] \
            && { COUNT=0; ARRAY_INDEX=$(($ARRAY_INDEX + 1)); } \
            || true; }; do

    if [[ $LINE == "#"* || $LINE == "" ]]; then
        continue
    fi

    if [[ $LINE == "DO_NOT_STOP_ON_FAILURE" ]]; then
        echo "$LINE" >> $SPLIT_OUTPUT_PREFIX$ARRAY_INDEX
        continue
    fi

    echo "$LINE" >> $SPLIT_OUTPUT_PREFIX$ARRAY_INDEX
    COUNT=$((COUNT + 1))
done

SPLIT_FILES=`ls $SPLIT_OUTPUT_PREFIX*`
for FILE in $SPLIT_FILES; do
    sed -i '1s/^/DUMPLIST_START\n/' $FILE
    echo "DUMPLIST_END" >> $FILE
done
exit 0