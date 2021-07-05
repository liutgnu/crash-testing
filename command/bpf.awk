#bpf
function bpf_filter(line)
{
	#eg: 13  ffffa4c10c569000 ffff9837fddf8d00  CGROUP_SKB   7be49e3934a125ba   13,14  
	if (match(line, ": bpf\\]$")) {
		allow_regx="command not supported or applicable on this architecture or kernel";
		allow_regx=allow_regx "|^\\s*[0-9 ]+";
		next;
	}

	#eg: 13  ffffa4c10c569000 ffff9837fddf8d00  CGROUP_SKB   7be49e3934a125ba   13,14
	#eg:     XLATED: 296  JITED: 229  MEMLOCK: 4096
	#eg:     LOAD_TIME: Thu Feb 25 04:47:20 2021
	if (match(line, ": bpf -PM\\]$")) {
		allow_regx="command not supported or applicable on this architecture or kernel";
		allow_regx=allow_regx "|^\\s*[A-Z_0-9]+:";
		allow_regx=allow_regx "|^\\s*[0-9]+ ";
		next;
	}

	#eg:  ops = 0xffffffff8c835a80, 
	#eg:  inner_map_meta = 0x0, 
	#eg:  0xffffffffc03c0ee2:	push   %rbp
	if (match(line, ": bpf -PM -jTs\\]$")) {
		allow_regx="command not supported or applicable on this architecture or kernel";
		allow_regx=allow_regx "|^\\s*[A-Z_0-9]+:";
		allow_regx=allow_regx "|^\\s*[0-9]+ ";
		allow_regx=allow_regx "|^\\s*[0-9a-fA-FxX]+:";
		allow_regx=allow_regx "|^\\s*[a-zA-Z0-9_ ]+=";
		next;
	}
}