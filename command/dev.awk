#dev
function dev_filter(line)
{
	#eg:   4      tty            ffff978845f6f200  tty_fops
	if (match(line, ": dev\\]$")) {
		allow_regx="^\\s*[0-9]+ ";
		next;
	}

	#eg:ffff97587e91d3c0  4000-40ff  hpsa
	if (match(line, ": dev -i\\]$")) {
		allow_regx="^\\[[a-f0-9]+ \\]";
		next;
	}

	#eg:  ffff97d7ffaf1000 0000:05:00.0  0200  8086:10fb  ENDPOINT
	if (match(line, ": dev -p\\]$")) {
		allow_regx="^[a-f0-9]+ |option not supported or applicable on this architecture or kernel";
		next;
	}

	#eg:  71 ffff980845f1a800   sdnt       ffff97b7f4e7cd80       1     0     1     1
	if (match(line, ": dev -d\\]$")) {
		allow_regx="^\\s*[0-9 ]+[a-f0-9]+ ";
		next;
	}

	if (match(line, ": dev -D\\]$")) {
		allow_regx="^\\s*[0-9 ]+[a-f0-9]+ ";
		next;
	}

	#eg:  1    0x2001240          33558464         cxgb4_0000:03:00.4
	if (match(line, ": dev -V\\]$")) {
		allow_regx="^\\s*[0-9]+ |dev: -V option not supported on this dumpfile type|dev: -V option not supported on a live system";
		next;
	}
}