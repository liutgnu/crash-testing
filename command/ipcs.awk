# ipcs
function ipcs_filter(line)
{
	#eg:ffff880473a28490 00000001 32769      0     666   90000      1
	if (match(line, ": ipcs\\]$")) {
		allow_regx="^\\s*[a-f0-9]+ ";
		next;
	}

	#eg:PAGES ALLOCATED/RESIDENT/SWAPPED: 22/1/0
	if (match(line, ": ipcs -M\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";
		next;
	}
}