#!/bin/bash

# The __error function have the following log categories,
# INFO
# FATAL
# FATAL_RESTART
# WARNING
# NOTE
# CONT

function log_filter()
{
        # The following options of grep are the allow list of messages.
        # The following options of awk are the deny list of messages. We use
        # awk because it can print matched lines as well as context lines.
        grep -v \
         -e 'bt: cannot determine NT_PRSTATUS ELF note for active task' \
         -e 'bt: WARNING: cannot determine starting stack frame for task' \
         -e 'cannot determine file and line number' \
         -e 'cannot be determined: try -t or -T options' \
         -e 'WARNING: kernel relocated' \
         -e 'WARNING: page fault at' \
         -e 'WARNING: FPU may be inaccurate' \
         -e 'WARNING: cannot find NT_PRSTATUS note for cp' \
         -e '_FAIL_' \
         -e 'PANIC:' \
         -e 'Instruction bus error  \[[0-9]*\] exception frame:' \
         -e '00000002: error' \
         -e 'error_' \
         -e 'ERROR_' \
         -e '-error' \
         -e '_error[^(.so)]' \
         -e 'Data Access error' \
         -e 'invalid float value' \
         -e 'fail_nth' \
         -e '_fail' \
         -e 'failsafe' \
         -e 'failover' \
         -e 'invalid_' \
         -e 'invalidate' \
         -e 'PCIBR error' \
         -e 'TIOCE error' \
         -e 'task_beah_unexpected' \
         -e 'arm-smmu-v3-gerror' \
         -e 'xlog_state_ioerror' \
         -e 'fail_page_alloc' \
         -e 'error: default' \
         -e 'failslab' \
         -e 'creds_are_invalid' \
         -e '00000100: error' \
         -e 'printk_ringbuffer.fail' \
         -e 'ps: cannot access user stack address' \
         -e 'mod: cannot find or load object file' \
         -e 'invalid option' \
         -e 'invalid UUID' \
         | \
        awk 'BEGIN{IGNORECASE = 1}

            # n==1 gives the regex matched line itself,
            # n>1 gives (n-1) more lines as context of the matched line.

            /warning/           {if (n < 1) n=1}
            /warnings/          {if (n < 1) n=1}
            /cannot/            {if (n < 1) n=1}
            /fail/              {if (n < 1) n=1}
            /error/             {if (n < 1) n=1}
            /invalid/           {if (n < 1) n=1}
            /absurdly large unwind_info/                {if (n < 1) n=1}
            /unexpected/        {if (n < 1) n=1}
            /crash: page excluded: kernel virtual address/ {if (n < 1) n=1}
            /zero-size memory allocation/               {if (n < 1) n=1}
            /dev: \-d option not supported or applicable on this architecture or kernel/ {if (n < 1) n=1}
            /dev: \-p option not supported or applicable on this architecture or kernel/ {if (n < 1) n=1}

            /\[Test 1]/                 {if (n < 1) n=1}
            /\[Test /                   {if (n < 1) {n=1; ahead="\n"}}
            /\[Dumpfile /               {if (n < 2) n=2}
            /\[Commandfile /            {if (n < 1) n=1}
            /Content compare BAD/       {if (n < 5) n=5}
            /FATAL<<<-->>>/             {if (n < 2) n=2}
            /FATAL_RESTART<<<-->>>/     {if (n < 2) n=2}
            /Exit values mismatch/      {if (n < 1) {n=1; ahead=""}}
            /Exit values are not 0/     {if (n < 1) {n=1; ahead=""}}
            /Crash returned with/       {if (n < 1) {n=1; ahead=""}}
            /Segmentation fault/        {if (n < 1) n=1}
            /No such file or directory/        {if (n < 1) n=1}
            /Permission denied/         {if (n < 1) n=1}
            n-- > 0 {
                # If a commandfile does not give any log, then we will not
                # print it out.
                if ($0 ~ /\[Commandfile /) {
                        ahead=$0"\n"
                } else {
                        printf("%s%s\n",ahead,$0);ahead=""
                }}'
}

# log_filter.sh can be called alone to filter offline logs.
# $1: logs file to be filtered
if [ ! $1 == "" ]; then
        if [ -f $1 ]; then
                cat $1 | log_filter
        else
                FILENAME=$(basename ${BASH_SOURCE[0]})
                [[ ! "$1" =~ -.* ]] && echo "$1 not exist!" 1>&2
                {
                        echo "Specify a log file to get filtered to standard output."
                        echo "Useage:"
                        echo -e "\t$FILENAME logfile"
                } 1>&2
        fi
        exit 0
fi

# log_filter.sh can also be used in a pipe:
# cat file.log | log_filter.sh
log_filter