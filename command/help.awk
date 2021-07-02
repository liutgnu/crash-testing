#help
function help_filter(line)
{
	if (match(line, ": help\\]$")) {
		allow_regx=".*";
		next;
	}

	#eg:    args[1]: 55bc3acb8c37: scroll
	if (match(line, ": help -a\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";
		next;
	}	

	if (match(line, ": help -b\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";
		next;
	}

	if (match(line, ": help -B\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";
		next;
	}

	if (match(line, ": help -c\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";
		next;
	}

	if (match(line, ": help -d\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";
		next;
	}

	#eg:   OFFSET(printk_ringbuffer.fail)=72
	#eg:   Item error[1][0] => position=0x22449c56f size=0x1: 01
	if (match(line, ": help -D\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:|^\\s*[A-Z]+\\([a-zA-Z_0-9\\.]+\\)=|error(\\[[0-9]+\\])+\\s+=>";
		next;
	}

	if (match(line, ": help -e\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";
		next;
	}

	if (match(line, ": help -f\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";
		next;
	}

	if (match(line, ": help -g\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";
		next;
	}
	
	if (match(line, ": help -h\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";
		next;
	}
	
	if (match(line, ": help -H\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";
		next;
	}
	
	if (match(line, ": help -k\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";
		next;
	}
	
	if (match(line, ": help -K\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";
		next;
	}
	
	if (match(line, ": help -L\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";
		next;
	}

	if (match(line, ": help -m\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";
		next;
	}

	if (match(line, ": help -n\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:|^\\s*[A-Z]+\\([a-zA-Z_0-9\\.]+\\)=|error(\\[[0-9]+\\])+\\s+=>";
		next;
	}

	if (match(line, ": help -N\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";
		next;
	}

	if (match(line, ": help -o\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";
		next;
	}

	if (match(line, ": help -p\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";
		next;
	}

	if (match(line, ": help -r\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";
		next;
	}

	if (match(line, ": help -s\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";
		next;
	}

	if (match(line, ": help -t\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";
		next;
	}

	#eg:[1979] ffff9837f2e30000 (chronyd)
	if (match(line, ": help -T\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:|^\\s*\\[[ 0-9]+\\]\\s*[a-z0-9]+";
		next;
	}

	if (match(line, ": help -v\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:|^\\s*\\[[ 0-9]+\\]\\s*[a-z0-9]+";
		next;
	}

	if (match(line, ": help -V\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:|^\\s*\\[[ 0-9]+\\]\\s*[a-z0-9]+";
		next;
	}

	if (match(line, ": help -x\\]$")) {
		allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:|^\\s*\\[[ 0-9]+\\]\\s*[a-z0-9]+";
		next;
	}

	#eg: -x - text cache
	if (match(line, ": help -z\\]$")) {
		allow_regx="^\\s*-[a-zA-Z]\\s*-";
		next;
	}
}