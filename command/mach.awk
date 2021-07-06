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
		if (match(ARCH, "ppc64")) {
			allow_regx=allow_regx "|'-m' option is not supported"
		}
		if (match(ARCH, "aarch64")) {
			allow_regx=allow_regx "|-m option not supported or applicable on this architecture or kernel"
		}
		next;
	}

	#eg:  x86_clflush_size = 64,
	if (match(line, ": mach -c\\]$")) {
		allow_regx="^\\s*[A-Za-z0-9_]+ =";
		if (match(ARCH, "ppc64")) {
			allow_regx=allow_regx "|'-c' option is not supported"
		}
		if (match(ARCH, "aarch64")) {
			allow_regx=allow_regx "|-c option not supported or applicable on this architecture or kernel"
		}
		next;
	}
}