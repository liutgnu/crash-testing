# sym
function sym_filter(line)
{
	#eg:ffffffff89e1a500 (T) schedule /usr/src/debug/kernel-4.18.0-57.el8/linux-4.18.0-57.el8.x86_64/kernel/sched/core.c: 3539
	if (match(line, ": sym schedule\\]$")) {
		allow_regx="^\\s*[0-9a-f]+\\s+\\([A-Za-z]\\) ";
		next;
	}
	
	if (match(line, ": sym -p -n schedule\\]$")) {
		allow_regx="^\\s*[0-9a-f]+\\s+\\([A-Za-z]\\) ";
		next;
	}
}