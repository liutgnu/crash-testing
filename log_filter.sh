#!/bin/bash

# The __error function have the following log categories,
# INFO
# FATAL
# FATAL_RESTART
# WARNING
# NOTE
# CONT
# 

# The left column is the identification string to filter out, the right column is
# the context line quantity, that is, current line plus n-1 lines behind current 
# line are filtered out.
FILTERING_LIST=(
        "Content compare BAD"   "5"
        "FATAL<<<-->>>"         "5"
        "FATAL_RESTART<<<-->>>" "5"
        "Exit values mismatch"  "1"
        "Exit values are not 0" "1"
        "Crash returned with"   "1"
        "Segmentation fault"    "1"
)

function log_filter()
{
        COUNTER=0
        FILTERING_LIST_LEN=$((${#FILTERING_LIST[@]} / 2))
        IS_FIRST_CASE="TRUE"
        while read LINE; do
                if [[ $LINE == "[Test "* ]]; then
                        if [ $IS_FIRST_CASE == "TRUE" ]; then
                                IS_FIRST_CASE="FALSE"
                        else
                                # Leave an empty line before every vmcore starts
                                echo
                        fi
                        COUNTER=1
                fi 
                if [[ $LINE == "[Dumpfile "* ]]; then
                        COUNTER=2
                fi
                if [[ $LINE == "[Commandfile "* ]]; then
                        COUNTER=1
                fi

                for((i=0;i<$FILTERING_LIST_LEN;i++)); do
                        if [[ $LINE == *"${FILTERING_LIST[$(($i * 2))]}"* ]]; then
                                COUNTER=${FILTERING_LIST[$(($i * 2 + 1))]}
                                break
                        fi
                done
                if [[ $COUNTER -gt 0 ]]; then
                        echo "$LINE"
                        COUNTER=$(($COUNTER-1))
                fi
        done
}