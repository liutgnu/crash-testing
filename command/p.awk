# p
flag=="p" && /: p linux_banner\]$/     {allow_regx="^\\s*linux_banner =";next;}

function p_filter(line)
{
	#eg:builtin  man      help
	if (match(line, ": p linux_banner\\]$")) {
		allow_regx="^\\s*linux_banner =";
		next;
	}
}