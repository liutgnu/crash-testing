# set
function set_filter(line)
{
	if (match(line, ": set\\]$")) {
		allow_regx="^\\s*[A-Z_ 0-9]+:";
		next;
	}

	#eg:     null-stop: off
	if (match(line, ": set -v\\]$")) {
		allow_regx="^\\s*[a-z\\-_ 0-9]+:";
		next;
	}
}