# sym_long
function sym_long_filter(line)
{
	if (match(line, ": sym -l\\]$")) {
		allow_regx="^\\s*[0-9a-f]+\\s+(\\([A-Za-z]\\)|MODULE)";
		next;
	}
}