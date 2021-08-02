#!/bin/bash

# $1: start test case
# $2: end test case
# $3: the file to split

FILE_NAME=$(basename ${BASH_SOURCE[0]})
usage()
{
	echo "Usage:"
	echo "$FILE_NAME <crash_log> <start_case> <end_case> "
	echo
	echo "Tool for splitting <crash_log> from <start_case> to <end_case>"
	echo "when we have a long list of testing cases. By using this tool, we"
	echo "can extract the specific cases to analyze in details. For example:"
	echo
	echo "crash.log:"
	echo "[Test 1]"
	echo "   content of test 1"
	echo "[Test 2]"
	echo "   content of test 2"
	echo "[Test 3]"
	echo "   content of test 3"
	echo
	echo "\$ $FILE_NAME 2 2 crash.log  #It will extract the content of Test 2" 
}

NUM_REGX='^[1-9]([0-9]+)?$'
if ! [[ "$2" =~ $NUM_REGX && "$3" =~ $NUM_REGX ]]; then
	usage
	exit 1
fi

if [[ $1 == "" || ! -f $1 ]]; then
	echo -e "Error \"$1\" not exist!\n"
	usage
	exit 1
fi

log_file=$1

file $log_file | grep "gzip" 2>&1 >/dev/null
if [ $? -eq 0 ]; then
	log_file="<(zcat $log_file)"
fi

[ $2 -lt $3 ] && { start=$2; end=$3; } || { end=$2; start=$3; }

start_case="\\\\[Test $start\\\\]"
end_case="\\\\[Test $(($end + 1))\\\\]"

awk_cmd="awk -v str1=\"\$start_case\" -v str2=\"\$end_case\" '
	BEGIN {
		start=0;
		end=0;
	}
	{
		if (match(\$0, str1)) {start=NR;}
		if (match(\$0, str2)) {end=NR;}
	}
	END {
		if (start==0) 
			{printf(\"0 0\");}
		else if (end==0) 
			{printf(\"%d %d\", start, NR);}
		else if (end <= start) 
			{printf(\"0 0\");}
		else 
			{printf(\"%d %d\", start, end-1);}
	}
'"

line_num=$(eval $awk_cmd $log_file)

if [[ $line_num == "0 0" ]]; then
	echo "The start and end exceeded range!"
	exit 1
fi
sed_cmd=$(echo $line_num|awk -v str="$log_file"  '{printf("sed -ne \"%d,%dp\" %s",$1,$2,str);}')
eval "$sed_cmd"