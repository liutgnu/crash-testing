#!/bin/bash

function live_test_filter()
{
    # In live testing, source code of crash-testing will be included in ENV of
    # some process, and ps -a will output the ENV of process, then filtered by
    # log_filter.
    # That is, the source code of log_filter.sh will be filtered by log_filter,
    # which is annoying. So we will strip the output of "ps -a" and similar
    # commands.

    # awk doesn't support look-ahead, so difficult to make regx for "deny all",
    # so we use a strange pattern for "deny all".
    awk -v LIVE_FLAG="$1" -F '[: \\[\\]]' '
        /^\[Dumpfile /              {allow_regx=".*";if($3=="live"){is_live="yes"}else{is_live="no"};print $0;next;}
        (is_live=="yes" || LIVE_FLAG=="yes") && /: ps -a\]$/ {allow_regx="/\\//\\\\\\/";print $0;next;}
        /^\[Command /               {allow_regx=".*";print $0;next;}
        
        $0 ~ allow_regx             {print $0;}
    '
}

function log_filter()
{
        # $1: arch
        LC_ALL=C AWKPATH="$CURRENT_DIR/command" \
                awk -v ARCH="$1" -F '[: \\[\\]]' -f $CURRENT_DIR/utils/log_filter.awk 
}

function format_output_for_each_crash_invoke()
{
        awk '
                /\[Test /       {n=0; array[n]=$0; next;}
                //              {array[++n]=$0; next;}
                END {
                        if (array[3] == "Crash returned with 0") {
                                printf("%s Pass\n", array[0]);
                        } else {
                                printf("%s Failed\n", array[0]);
                                for (x=1; x<=n; x++) {
                                        print array[x];
                                }
                        }
                        delete array;
                }'
}

function format_output_for_log_file()
{
        awk '
                /\[Test 1\]/ {array[0]=$0; next}
                /\[Test / {
                        if (array[3] == "Crash returned with 0") {
                                printf("%s Pass\n", array[0]);
                        } else {
                                printf("%s Failed\n", array[0]);
                                for (x=1; x<=n; x++) {
                                        print array[x];
                                }
                        }
                        delete array;
                        n=0; array[n]=$0; next;
                }
                //      {array[++n]=$0;}
                END {
                        if (array[3] == "Crash returned with 0") {
                                printf("%s Pass\n", array[0]);
                        } else {
                                printf("%s Failed\n", array[0]);
                                for (x=1; x<=n; x++) {
                                        print array[x];
                                }
                        }
                        delete array;
                }'
}

function output_summary()
{
    awk '
        BEGIN                       {total=0;pass=0;fail=0;}
        /^\[Test .*\] Pass$/        {total+=1;pass+=1;print $0;next;}
        /^\[Test .*\] Failed$/      {total+=1;fail+=1;print $0;next;}
        {print $0;next;}
        END {
            printf("\n---------Test Summary---------\n");
            printf("Total: %d tests\n",total);
            printf("Pass: %d tests\n",pass);
            printf("Fail: %d tests\n",fail);
        }'
}

# $1: logs file to be filtered
function filter_log_file()
{
        if [ -f $1 ]; then
                file $1 | grep "gzip" 2>&1 >/dev/null
                if [ $? -eq 0 ]; then
                        zcat $1 | live_test_filter | log_filter $(arch) | uniq | format_output_for_log_file | output_summary
                else
                        cat $1 | live_test_filter| log_filter $(arch) | uniq | format_output_for_log_file | output_summary
                fi
        fi
}