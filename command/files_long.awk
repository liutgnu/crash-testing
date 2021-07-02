#files_long
function files_long_filter(line)
{
	if (match(line, ": foreach files\\]$")) {
		allow_regx="^\\s*[0-9]+\\s+[0-9a-f]+";
		next;
	}
}