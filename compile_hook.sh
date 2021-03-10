#!/bin/bash
SHOULD_RESET_SELINUX="FALSE"

function compile_hook()
{
    cd $(dirname $HOOK_ERROR_SO)
    echo "Making hook-error..."
    make
    if ! [[ $? -eq 0 && -f $HOOK_ERROR_SO ]]; then
        {
            echo "Compile hook-error failed."
            echo "Hook-error is used for better error log filtering."
            echo "You can still pass -m option to run the test without better filtering."
            echo
        } 1>&2
        exit 1
    fi

    SELINUX_STATUS="$(getenforce)"
    if [[ "$SELINUX_STATUS" == "Enforcing" ]]; then
        {
            echo "WARNING: We will use heap execution to perform crash log filtering,"
            echo "thus we need to aquire ROOT privilege to temporarily set selinux"
            echo "status to Permissive, proceed?"
            echo
            echo -n "enter <RETURN> to continue: "
            read INPUT
        } 1>&2
        sudo setenforce 0
        if [[ $? -ne 0 ]]; then
            echo "Selinux setenforce 0 failed!" 1>&2
            exit 1
        fi
        SHOULD_RESET_SELINUX="TRUE"
    fi
    export CRASH_ENV="$HOOK_ERROR_SO"
    cd ~-
}

function check_and_compile_hook()
{
    if [[ "$ARCH" == "x86_64" || "$ARCH" =~ i.86 ]]; then
        compile_hook
    else
        echo "Warning: hook-error is not implemented for arch $ARCH"
        echo "Continue testing without good error log filtering."
        echo
        echo -n "enter <RETURN> to continue: "
        read INPUT
    fi
}

function test_and_restore_selinux()
{
    if [[ $SHOULD_RESET_SELINUX == "TRUE" ]]; then
        sudo setenforce 1
    fi
}