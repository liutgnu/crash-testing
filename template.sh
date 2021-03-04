#!/bin/bash
# This file is part of crash_tesh.sh.
# This is the template implementation for variable support of command testing.
# You can take command/vtop_ptov_validation as reference to get a 
# general view of template.

TIMEOUT=300 # 5minute
while true; do
    SUFFIX=$RANDOM
    if ! [ -f $TEMPLATE_PIPE_PREFIX$SUFFIX ]; then
        PIPE=$TEMPLATE_PIPE_PREFIX$SUFFIX
        break;
    fi
done

function init_template()
{
    mkfifo $PIPE
}

function exit_template()
{
    rm -f $PIPE
}

function sync_with_crash()
{
    local KEY=$RANDOM
    # Ask crash to give us response.
    # Note crash treats prefix ! as gdb commands,
    # we use gdb echo instead of crash echo because
    # redirection of crash externel commands doesn't work. 
    echo "! echo $KEY > $PIPE"
    while true; do
        sleep 1
        echo -e "\n"
        local TMP=\"$(cat 0<>$PIPE <$PIPE)\"
        if [[ "$TMP" == \""$KEY\"" ]]; then
            break
        fi
    done
}

function run_template()
{
    local TEMPLATE_ORIGIN_LINE_REGX="^@(.*)$"
    local TEMPLATE_VARNAME_REGX="\{\{\s*[a-zA-Z0-9_]+\s*\}\}"
    local TEMPLATE_ASSGIN_VARNAME_REGX=">[ \t]*"$TEMPLATE_VARNAME_REGX
    local TEMPLATE_GET_REST_THAN_ASSGIN_REGX="(.*)"$TEMPLATE_ASSGIN_VARNAME_REGX

    while read LINE; do
        # Check if line start with '@', which indicates it should be processed
        # by template.
        if [[ ! "$LINE" =~ $TEMPLATE_ORIGIN_LINE_REGX ]]; then
            echo "$LINE"
            continue
        fi
        LINE=${BASH_REMATCH[1]}
        
        # Check if line contains '{{var}}', which should be processed by
        # template.
        if [[ ! "$LINE" =~ $TEMPLATE_VARNAME_REGX ]]; then
            echo "$LINE"
            continue
        else
            # Extract all '{{var}}'s to array.
            ALL_TEMPLATE_VARS=($(echo "$LINE" | grep -Eo "$TEMPLATE_VARNAME_REGX"))
        fi
        
        # Check if line contains '> {{var}}'s, which are template var assginment.
        if [[ "$LINE" =~ $TEMPLATE_ASSGIN_VARNAME_REGX ]]; then
            # Store these '{{var}}'s to array.
            ALL_TEMPLATE_ASSIGN_VARS=($(echo "$LINE" | \
                grep -Eo "$TEMPLATE_ASSGIN_VARNAME_REGX" | \
                sed 's/[> \t]//g'))
            if [[ ${#ALL_TEMPLATE_ASSIGN_VARS[@]} -gt 1 ]]; then
                echo "We currently only support maximun 1 template variable assignment per-line!" 1>&2
                exit 1
            fi
            ASSIGN_TEMPLATE_VAR="${ALL_TEMPLATE_ASSIGN_VARS[0]}"
        else
            ASSIGN_TEMPLATE_VAR=""
        fi

        # ALL_TEMPLATE_VARS contains both '> {{var}}'s and non '> {{var}}'s.
        # The difference is the former one is variable assignment, the latter is
        # to get the value of the variable. So we exclude the former set to get
        # the latter set.
        ALL_EVAL_TEMPLATE_VARS=(${ALL_TEMPLATE_VARS[@]/$ASSIGN_TEMPLATE_VAR})

        # 1st, process variable evaluating.
        # We replace all template evaluating variables with their values.
        for ((i=0;i<${#ALL_EVAL_TEMPLATE_VARS[@]};i++)); do
            VR=$(echo "${ALL_EVAL_TEMPLATE_VARS[$i]}" | sed 's/[{}]//g')
            if [[ ${!VR} == "" ]]; then
                # All template variables should be assigned first, then evaluate.
                echo "${ALL_EVAL_TEMPLATE_VARS[$i]} undefined!" 1>&2
                exit 1
            fi
            ESCAPED_TEMPLATE_VAR=$(echo "${ALL_EVAL_TEMPLATE_VARS[$i]}" | \
                sed 's/{/\\\{/g' | \
                sed 's/}/\\\}/g')
            LINE=$(echo $LINE | sed -E "s/$ESCAPED_TEMPLATE_VAR/${!VR}/")
        done

        # 2nd, process variable assignment.
        # We replace the template assignment variable with named pipe.
        if [[ "$LINE" =~ $TEMPLATE_GET_REST_THAN_ASSGIN_REGX ]]; then
            # Sometimes when we run crash_test.sh in multi-thread(-u),
            # it can take long time to schedule a crash process, this
            # always timeout the template. Thus we sync here, making sure when
            # template is waiting for crash give back the value, 
            # crash is actually running.
            sync_with_crash
            VR=$(echo $ASSIGN_TEMPLATE_VAR | sed -E "s/[{}]//g")
            eval "$VR"=""
            # Now get the non-assign part, assemble it with pipe.
            # Eg: From 'xxx > {{var}}' to 'xxx > $PIPE'
            # After pass the string to crash, crash will execute the line by
            # redirecting the output to the pipe.
            echo "${BASH_REMATCH[1]} > $PIPE"
            # Now we read from pipe, get the value of {{var}}
            for((i=0;i<$TIMEOUT;i++)); do
                sleep 1
                # This echo is used to check pipe's functionality, or the 
                # status of crash process. If crash has exited due to some
                # error, when echo here, we will receive SIGPIPE, which will 
                # terminate the script.
                echo -e "\n"
                # Non-block cat the named pipe.
                local TMP=\"$(cat 0<>$PIPE <$PIPE)\"
                if [[ ! "$TMP" == "\"\"" ]]; then
                    eval "$VR"=$TMP
                    break
                fi
            done
            if [ $i -ge $TIMEOUT ]; then
                # Ask crash to print out error log.
                echo "echo Template timeout..."
                # If crash dosen't give us the {{var}} value in a given period 
                # of time, template will exit. In case crash writes to the named
                # pipe afterwards(no reader and will hangup forever), we delete
                # the pipe, and crash will create a regular file named $PIPE,
                # which is a non-blocking write process, so we are good.
                rm -f $PIPE
                exit 1
            fi
        else
            # If no template variable assignment, do nothing.
            echo $LINE
        fi
    done
}