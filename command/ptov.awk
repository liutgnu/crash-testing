#ptov
function ptov_filter(line)
{
	#eg: ffff8fe9c0000000  0
	if (match(line, ": ptov 0\\]$")) {
		allow_regx="^\\s*[0-9a-f]+\\s+[0-9a-f]+";
		next;
	}
}