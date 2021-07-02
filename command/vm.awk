# vm
function vm_filter(line)
{
	#eg:ffff899f5e1113e8 557f53791000 557f537ca000 8000871 /root/usr/bin/bash
	if (match(line, ": vm\\]$")) {
		allow_regx="^\\s*[a-f0-9]+\\s*[a-f0-9]+\\s*[a-f0-9]+|WARNING: malloc/free mismatch";
		next;
	}

	if (match(line, ": vm -m\\]$")) {
		allow_regx="^\\s*[a-z_]+ =|WARNING: malloc/free mismatch";
		next;
	}
}