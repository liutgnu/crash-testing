#rd
function rd_filter(line)
{
	#eg:ffffffff8a400100:  4c 69 6e 75 78 20 76 65 72 73 69 6f 6e 20 34 2e   Linux version 4.
	if (match(line, ": rd -8 linux_banner 256\\]$")) {
		allow_regx="^\\s*[0-9a-f]+:  ([0-9a-f]{2} ){16}";
		next;
	}
}