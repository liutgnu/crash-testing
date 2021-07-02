# mach
function mach_filter(line)
{
	#eg:          MACHINE TYPE: x86_64
	if (match(line, ": mach\\]$")) {
		allow_regx="^\\s*[A-Z 0-9]+:";
		next;
	}

	#eg:    000000001ff75000 - 000000001ff77000  E820_NVS
	if (match(line, ": mach -m\\]$")) {
		allow_regx="^\\s*[a-f0-9]+ - [a-f0-9]+";
		next;
	}

	#eg:  x86_clflush_size = 64,
	if (match(line, ": mach -c\\]$")) {
		allow_regx="^\\s*[A-Za-z0-9_]+ =";
		next;
	}
}