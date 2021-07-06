# net
function net_filter(line)
{
	if (match(line, ": net\\]$")) {
		allow_regx="^\\s*[a-f0-9]+ +[a-z0-9]+";
		next;
	}

	#eg:ffff8fead9ac9200 0.0.0.0         UNKNOWN    00 00 00 00 00 00  lo      NOARP
	#eg:3fa348800        172.31.131.162  ETHER      00:00:00:00:00:00  bond0.1861  FAILED
	if (match(line, ": net -a\\]$")) {
		allow_regx="^\\s*[a-f0-9]+ [0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+";
		allow_regx=allow_regx "|\\s+FAILED$"
		next;
	}

	#eg:104 ffff8feada20a940 ffff8feada8d8000 INET6:STREAM
	if (match(line, ": net -s 1\\]$")) {
		allow_regx="^\\s*[0-9]+ +[a-f0-9]+ +[a-f0-9]+";
		next;
	}
}