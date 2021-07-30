#!/bin/bash

# $1: progress named pipe suffix
export NAMED_PIPE_IN="/tmp/progress_in_$1"
export NAMED_PIPE_OUT="/tmp/progress_out_$1"
PROGRESS_LOCK="/tmp/progress_lock_$1"
UPDATE_PID=0

function init_progress()
{
	# If tput and flock is not available, progress display should be
	# disabled.
	which tput 2>/dev/null 1>/dev/null
	local exit_val=$?
	which flock 2>/dev/null 1>/dev/null
	local exit2_val=$?
	if ! [[ $exit_val -eq 0 && $exit2_val -eq 0 ]]; then
		return
	fi

	if [[ ! -p $NAMED_PIPE_IN &&  ! -p $NAMED_PIPE_OUT ]]; then
		mkfifo $NAMED_PIPE_IN
		mkfifo $NAMED_PIPE_OUT
		touch $PROGRESS_LOCK
		update_progress &
		UPDATE_PID=$!
	fi
}

function update_progress()
{
	CURRENT=0
	while true; do
		cmd=$(cat $NAMED_PIPE_IN)
		case $cmd in

		'i') CURRENT=$(( $CURRENT + 1 ))
		;;

		'e') break
		;;

		'g') timeout 2 bash -c "echo $CURRENT > $NAMED_PIPE_OUT"
		;;

		*)
		;;
		esac
	done
	rm -f $NAMED_PIPE_IN
	rm -f $NAMED_PIPE_OUT
	rm -f $PROGRESS_LOCK
}

function send_progress()
{
	# $1(cmd) must be:'i', 'e', 'g'
	if [[ $1 == 'i' || $1 == 'e' || $1 == 'g' ]]; then
		echo $1 > $NAMED_PIPE_IN
	fi
}
export -f send_progress

# Only called by main process
function clean_progress()
{
	if [ $UPDATE_PID -ne 0 ]; then
		kill -SIGTERM $UPDATE_PID 2>/dev/null
		UPDATE_PID=0
	fi
	rm -f $NAMED_PIPE_IN
	rm -f $NAMED_PIPE_OUT
	rm -f $PROGRESS_LOCK
}
##############################################

# Called by main process
function exit_progress()
{
	if [ -p $NAMED_PIPE_IN ]; then
		flock $PROGRESS_LOCK -c "end_progress \"e\""
	fi
}

# Called by main process
function get_progress()
{
	if [[ -p $NAMED_PIPE_IN && -p $NAMED_PIPE_OUT ]]; then
		flock $PROGRESS_LOCK -c "send_progress \"g\"; timeout 2 cat $NAMED_PIPE_OUT"
		if [ $? -ne 0 ]; then
			echo 0
		fi
	fi
}

# Called by main and subprocess
function increase_progress()
{
	if [ -p $NAMED_PIPE_IN ]; then
		flock $PROGRESS_LOCK -c "send_progress \"i\""
	fi
}

function output_progress()
{
	# $1 total cases
	if ! [[ -p $NAMED_PIPE_IN && -p $NAMED_PIPE_OUT ]]; then
		while read -r line; do
			echo "$line"
		done
		return
	fi
	while read -r line; do
		local row=$(tput lines)
		local col=$(tput cols)

		tput cup $(( $row - 1 )) 0
		printf "%${col}s\r" ""
		echo "$line"

		local current_quantity=$(get_progress)
		[ $current_quantity -eq 0 ] && continue
		tput cup $(( $row + 1 )) 0;
		echo -ne '\t\t'"Current($current_quantity)/Total($1)"'\r'
	done
}
