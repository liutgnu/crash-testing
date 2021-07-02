# swap
function swap_filter(line)
{
	#eg:ffff8fead7ac0000  PARTITION  4169724k     8716k     0%   -2  /dev/dm-1
	if (match(line, ": swap\\]$")) {
		allow_regx="^\\s*[0-9a-f]+\\s+[A-Z_]+";
		next;
	}
}