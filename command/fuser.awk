#fuser
function fuser_filter(line)
{
	#eg: 4706  ffff9817f02b15c0  "kworker/55:2"   root cwd
	if (match(line, ": fuser \\/\\]$")) {
		allow_regx="^\\s*[0-9]+\\s+[0-9a-f]+";
		next;
	}
}