# net_long
function net_long_filter(line)
{
	#eg:      skc_ipv6only = 0 , 
	if (match(line, ": net -S\\]$")) {
		allow_regx="^\\s*[a-z0-9_]+ =";
		next;
	}

	if (match(line, ": foreach net -s\\]$")) {
		allow_regx="^\\s*PID: |^\\s*[0-9]+\\s+[0-9a-f]+\\s+[0-9a-f]+";
		next;
	}
}