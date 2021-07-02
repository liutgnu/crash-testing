#files
function files_filter(line)
{
	#eg:  0  c6b9c740  c7cc45a0  c7c939e0  CHR   /dev/null
	if (match(line, ": files\\]$")) {
		allow_regx="^\\s*[0-9]+\\s+[0-9a-f]+";
		next;
	}

	if (match(line, ": files -c\\]$")) {
		allow_regx="^\\s*[0-9]+\\s+[0-9a-f]+";
		next;
	}
}