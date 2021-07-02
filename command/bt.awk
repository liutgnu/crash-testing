#bt
function bt_filter(line)
{
	#eg:PID: 0      TASK: ffffffff8cc10740  CPU: 0   COMMAND: "swapper/0"
	#eg:  #0 [fffffe0000008a10] machine_kexec at ffffffff8ba5176e
	#eg:--- <NMI exception stack> ---
	#eg:    R13: 0000000000000003  R14: ffffffff8c899170  R15: ffff97587d15fb45
	if (match(line, ": bt\\]$")) {
		allow_regx="[A-Z0-9_]+: |\\[[a-f0-9]+\\] |---";
		next;
	}

	if (match(line, ": bt -a\\]$")) {
		allow_regx="[A-Z0-9_]+: |\\[[a-f0-9]+\\] |---|option not supported on a live system or live dump|cannot be determined: try -t or -T options";
		next;
	}
	
	if (match(line, ": bt -c 0\\]$")) {
		allow_regx="[A-Z0-9_]+: |\\[[a-f0-9]+\\] |---|option not supported on a live system or live dump|cannot be determined: try -t or -T options";
		next;
	}
	
	if (match(line, ": bt -g\\]$")) {
		allow_regx="[A-Z0-9_]+: |\\[[a-f0-9]+\\] |---";
		next;
	}

	#eg:ffffffff8cc03f60:  0000000000000000 0000000000000000
	if (match(line, ": bt -r\\]$")) {
		allow_regx="[A-Z0-9_]+: |^[a-f0-9]+: ";
		next;
	}

	if (match(line, ": bt -t\\]$")) {
		allow_regx="[A-Z0-9_]+: |\\[[a-f0-9]+\\] |---";
		next;
	}

	if (match(line, ": bt -T\\]$")) {
		allow_regx="[A-Z0-9_]+: |\\[[a-f0-9]+\\]";
		next;
	}	

	#eg:    /usr/src/debug/kernel-4.18.0-3/arch/x86/kernel/machine_kexec_64.c: 339
	if (match(line, ": bt -l\\]$")) {
		allow_regx="[A-Z0-9_]+: |\\[[a-f0-9]+\\] |---|: [0-9]+";
		next;
	}
	
	if (match(line, ": bt -e\\]$")) {
		allow_regx="[A-Z0-9_]+: |option not supported or applicable on this architecture or kernel";
		next;
	}	

	#eg:CPU 124 DEBUG EXCEPTION STACK:
	if (match(line, ": bt -E\\]$")) {
		allow_regx="[A-Z0-9_]+: |[A-Z0-9_]+:$|option not supported or applicable on this architecture or kernel";
		next;
	}

	if (match(line, ": bt -f\\]$")) {
		allow_regx="[a-f0-9]+: |\\[[a-f0-9]+\\] |---|[A-Z0-9_]+: ";
		next;
	}

	if (match(line, ": bt -F\\]$")) {
		allow_regx="[a-f0-9]+: |\\[[a-f0-9]+\\] |---|[A-Z0-9_]+: ";
		next;
	}

	if (match(line, ": bt -FF\\]$")) {
		allow_regx="[a-f0-9]+: |\\[[a-f0-9]+\\] |---|[A-Z0-9_]+: ";
		next;
	}

	if (match(line, ": bt -o\\]$")) {
		allow_regx="\\[[a-f0-9]+\\] |---|[A-Z0-9_]+: |option not supported or applicable on this architecture or kernel";
		next;
	}

	if (match(line, ": bt -v\\]$")) {
		allow_regx="possible stack overflow: |bt: invalid kernel virtual address: 0|option not supported or applicable on this architecture or kernel";
		next;
	}

	if (match(line, ": bt -p\\]$")) {
		allow_regx="\\[[a-f0-9]+\\] |---|[A-Z0-9_]+: |option not supported on a live system or live dump";
		next;
	}

	if (match(line, ": bt -s\\]$")) {
		allow_regx="\\[[a-f0-9]+\\] |---|[A-Z0-9_]+: ";
		next;
	}

	if (match(line, ": bt -sx\\]$")) {
		allow_regx="\\[[a-f0-9]+\\] |---|[A-Z0-9_]+: ";
		next;
	}

	if (match(line, ": foreach bt\\]$")) {
		allow_regx="\\[[a-f0-9]+\\] |---|[A-Z0-9_]+: |cannot be determined: try -t or -T options";
		next;
	}
}