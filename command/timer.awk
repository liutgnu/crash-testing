# timer
function timer_filter(line)
{
	if (match(line, ": timer\\]$")) {
		allow_regx="^\\s*[0-9]+\\s+[0-9]+\\s+[a-f0-9]+\\s+[a-f0-9]+|WARNING: malloc/free mismatch";
		next;
	}

	if (match(line, ": timer -r\\]$")) {
		allow_regx="^\\s*[0-9]+\\s+[0-9]+\\s+[0-9]+|option not supported or applicable on this architecture or kernel|WARNING: malloc/free mismatch";
		next;
	}
}