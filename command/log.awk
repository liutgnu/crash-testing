# log
function log_filter(line)
{
	if (match(line, ": log\\]$")) {
		allow_regx=".*";
		next;
	}

	if (match(line, ": log -T\\]$")) {
		allow_regx="option not supported or applicable on this architecture or kernel";
		allow_regx=allow_regx "|^\\[.+[0-2][0-9]:[0-5][0-9]:[0-5][0-9].+\\]";
		next;
	}

	if (match(line, ": log -t\\]$")) {
		allow_regx=".*";
		next;
	}

	if (match(line, ": log -d\\]$")) {
		allow_regx="option not supported or applicable on this architecture or kernel";
		allow_regx=allow_regx "|^\\[\\s*[0-9]+\\.[0-9]+\\]";
		next;
	}

	#eg:[   11.036522] <6>scsi 1:0:0:0: alua: rtpg failed with 8000002
	#eg:<6>scsi 1:0:0:0: alua: rtpg failed with 8000002
	if (match(line, ": log -m\\]$")) {
		allow_regx="^\\s*(\\[\\s*[0-9]+\\.[0-9]+\\] )?<[0-7]>";
		next;
	}
	
	if (match(line, ": log -a\\]$")) {
		allow_regx="^type=[0-9]+ audit\\(";
		allow_regx=allow_regx "|option not supported or applicable on this architecture or kernel";
		next;
	}	
}