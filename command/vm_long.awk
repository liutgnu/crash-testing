# vm_long
function vm_long_filter(line)
{
	if (match(line, ": vm -p\\]$")) {
		allow_regx="^\\s*[a-f0-9]+ ";
		next;
	}

	if (match(line, ": vm -v\\]$")) {
		allow_regx="^\\s*[a-z_]+ =";
		next;
	}
}