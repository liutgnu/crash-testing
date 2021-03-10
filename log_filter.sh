#!/bin/bash

# The __error function have the following log categories,
# INFO
# FATAL
# FATAL_RESTART
# WARNING
# NOTE
# CONT
# 

FILTERING_LIST=(
        "Content compare BAD"
        "FATAL<<<-->>>"
        "FATAL_RESTART<<<-->>>"
        "Exit values mismatch"
        "Exit values are not 0"
)

function log_filter()
{
        COUNTER=0
        while read LINE; do
                if [[ $LINE == "[Test "* ]]; then
                       COUNTER=1
                fi 
                if [[ $LINE == "[Dumpfile "* ]]; then
                       COUNTER=2
                fi
                if [[ $LINE == "[Commandfile "* ]]; then
                       COUNTER=1
                fi

                for((i=0;i<${#FILTERING_LIST[@]};i++)); do
                        if [[ $LINE == *"${FILTERING_LIST[$i]}"* ]]; then
                                # Keep 5 lines as log context
                                COUNTER=5
                                break
                        fi
                done
                if [[ $COUNTER -gt 0 ]]; then
                        echo "$LINE"
                        COUNTER=$(($COUNTER-1))
                fi
        done
}