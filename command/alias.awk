#alias
function alias_filter(line)
{
	#eg:builtin  man      help
	if (match(line, ": alias\\]$")) {
		allow_regx="builtin ";
		next;
	}
}