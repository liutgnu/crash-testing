# mount
function mount_filter(line)
{
	#eg:ffff8feadbb36a80 ffff8feac7c0c800 proc   proc      /proc
	if (match(line, ": mount\\]$")) {
		allow_regx="^\\s*[a-f0-9]+ +[a-f0-9]+ ";
		next;
	}

	#eg:c6d02000  c6d0fc20  REG   usr/X11R6/lib/libICE.so.6.3
	if (match(line, ": mount -f\\]$")) {
		allow_regx="option not supported or applicable on this architecture or kernel";
		allow_regx=allow_regx "|^\\s*[a-f0-9]+ +[a-f0-9]+ ";
		next;
	}

	#eg:c72c4008
	if (match(line, ": mount -i\\]$")) {
		allow_regx="option not supported or applicable on this architecture or kernel";
		allow_regx=allow_regx "|^\\s*[a-f0-9]+";
		next;
	}
}