# task
function task_filter(line)
{
	#eg:    syscall_work = 0,
	if (match(line, ": task\\]$")) {
		allow_regx="^\\s*[a-z_]+ =";
		next;
	}
}