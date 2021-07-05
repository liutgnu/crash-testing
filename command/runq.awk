#runq
function runq_filter(line)
{
	#eg:CPU 1 RUNQUEUE: ffff8feadbb22900
	if (match(line, ": runq\\]$")) {
		allow_regx="^\\s*[A-Z 0-9_]+:";
		next;
	}

	#eg:CPU 0: 2680990637359
	#eg:       2680986653330  PID: 28228  TASK: ffff880037ca2ac0  COMMAND: "loop"
	if (match(line, ": runq -t\\]$")) {
		allow_regx="^\\s*CPU [0-9]+: ";
		allow_regx=allow_regx "|^\\s*[0-9]+\\s+PID: ";
		next;
	}

	#eg:  CPU 0: 0.00 secs
	if (match(line, ": runq -T\\]$")) {
		allow_regx="^\\s*CPU [0-9]+:\\s+[0-9]+.[0-9]+";
		next;
	}

	#eg: CPU 1: [0 00:00:00.000]  PID: 20688  TASK: ffff8feac033ab80  COMMAND: "bash"
	if (match(line, ": runq -m\\]$")) {
		allow_regx="^\\s*CPU [0-9]+:\\s+\\[";
		next;
	}

	if (match(line, ": runq -g\\]$")) {
		allow_regx="^\\s*[A-Z_ ]+:";
		allow_regx=allow_regx "|^\\s*\\[[0-9 ]+\\] PID:";
		allow_regx=allow_regx "|option not supported or applicable on this architecture or kernel";
		next;
	}

	#eg:CPU 0 RUNQUEUE: ffff8feadba22900
	if (match(line, ": runq -c 0\\]$")) {
		allow_regx="^\\s*[A-Z_ 0-9]+:";
		next;
	}
}