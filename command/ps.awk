# ps
function ps_filter(line)
{
	#eg:> 20688  20687   1  ffff8feac033ab80  RU   0.1   25384   4020  bash
	if (match(line, ": ps\\]$")) {
		allow_regx="^\\s*>?\\s*[0-9]+\\s*[0-9]+\\s*[0-9]+\\s*[0-9a-f]+";
		next;
	}

	if (match(line, ": ps -k\\]$")) {
		allow_regx="^\\s*>?\\s*[0-9]+\\s*[0-9]+\\s*[0-9]+\\s*[0-9a-f]+";
		next;
	}

	if (match(line, ": ps -u\\]$")) {
		allow_regx="^\\s*>?\\s*[0-9]+\\s*[0-9]+\\s*[0-9]+\\s*[0-9a-f]+";
		next;
	}

	if (match(line, ": ps -G\\]$")) {
		allow_regx="^\\s*>?\\s*[0-9]+\\s*[0-9]+\\s*[0-9]+\\s*[0-9a-f]+";
		next;
	}

	if (match(line, ": ps -s\\]$")) {
		allow_regx="^\\s*>?\\s*[0-9]+\\s*[0-9]+\\s*[0-9]+\\s*[0-9a-f]+";
		next;
	}

	if (match(line, ": ps -A\\]$")) {
		allow_regx="^\\s*>?\\s*[0-9]+\\s*[0-9]+\\s*[0-9]+\\s*[0-9a-f]+";
		next;
	}

	#eg: PID: 2      TASK: ffff8feac7785700  CPU: 1   COMMAND: "kthreadd"
	if (match(line, ": ps -p\\]$")) {
		allow_regx="^\\s*PID: [0-9]+\\s+TASK: ";
		next;
	}

	if (match(line, ": ps -c\\]$")) {
		allow_regx="^\\s*PID: [0-9]+\\s+TASK: ";
		next;
	}

	#eg:  START TIME: 34000000
	#eg:PID: 706    TASK: ffff8800497a8340  CPU: 1   COMMAND: "logical error i"
	if (match(line, ": ps -t\\]$")) {
		allow_regx="^\\s*[A-Z ]: |^\\s*PID: ";
		next;
	}

	#eg:[68067836650436] [IN]  PID: 17481  TASK: ffff8fead750d700  CPU: 0   COMMAND: "sleep"
	if (match(line, ": ps -l\\]$")) {
		allow_regx="^\\s*\\[[0-9 ]+\\] +\\[[A-Z]+\\]";
		next;
	}

	#eg:[0 00:00:07.698] [IN]  PID: 698    TASK: ffff8fead8fd2b80  CPU: 1   COMMAND: "sssd"
	if (match(line, ": ps -m\\]$")) {
		allow_regx="^\\s*\\[[0-9 :.]+\\] +\\[[A-Z]+\\]";
		next;
	}

	if (match(line, ": ps -m -C 0\\]$")) {
		allow_regx="^\\s*\\[[0-9 :.]+\\] +\\[[A-Z]+\\]";
		next;
	}

	#eg:PID: 1      TASK: ffff8feac7784140  CPU: 0   COMMAND: "systemd"
	#eg:ARG: /usr/local/Tivoli/fusa/ep/bin/linux-ix86/JRE/DMAE/bin/exe/java
	#eg:ENV:      HAL_PROP_INFO_CAPABILITIES=cpufreq_control
	if (match(line, ": ps -a\\]$")) {
		allow_regx="^\\s*PID: [0-9]+\\s+TASK: |^\\s*(ENV:)?\\s*[A-Z_0-9]+=|^\\s*ARG: |ps: cannot access user stack address:";
		next;
	}

	if (match(line, ": ps -g\\]$")) {
		allow_regx="^\\s*PID: [0-9]+\\s+TASK: ";
		next;
	}

	#eg:         CPU   (unlimited)   (unlimited)
	if (match(line, ": ps -r\\]$")) {
		allow_regx="^\\s*[A-Z]+";
		next;
	}

	#eg:  IN: 87
	if (match(line, ": ps -S\\]$")) {
		allow_regx="^\\s*[A-Z]+: [0-9]+";
		next;
	}
}