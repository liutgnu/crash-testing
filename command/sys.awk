# sys
function sys_filter(line)
{
	if (match(line, ": sys\\]$")) {
		allow_regx="^\\s*[A-Z ]+:";
		next;
	}
	
	if (match(line, ": sys -c\\]$")) {
		allow_regx="^\\s*[0-9 ]+";
		next;
	}

	if (match(line, ": sys -t\\]$")) {
		allow_regx="^\\s*[A-Z_ ]+";
		next;
	}

	if (match(line, ": sys -i\\]$")) {
		allow_regx="^\\s*[A-Z_ ]+";
		next;
	}

	#eg:# EDAC - error detection and reporting (RAS) (EXPERIMENTAL)
	if (match(line, ": sys config\\]$")) {
		allow_regx="^\\s*[A-Z_0-9]+=|^\\s*# ";
		next;
	}
}
