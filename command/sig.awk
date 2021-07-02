# sig
function sig_filter(line)
{
	#eg:[61] ffff8feacb3f2888    SIG_DFL 0000000000000000 0
	#eg:    SIGNAL: 0000000000000000
	if (match(line, ": sig\\]$")) {
		allow_regx="^\\s*\\[[0-9 ]+\\]\\s+[0-9a-f]+|^\\s*[A-Z_]+:";
		next;
	}

	if (match(line, ": sig -g\\]$")) {
		allow_regx="^\\s*\\[[0-9 ]+\\]\\s+[0-9a-f]+|^\\s*[A-Z_]+:";
		next;
	}

	#eg:[32] SIGRTMIN
	if (match(line, ": sig -l\\]$")) {
		allow_regx="^\\s*\\[[0-9 ]+\\]\\s+[A-Z]+";
		next;
	}
}