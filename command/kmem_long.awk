# kmem_long
function kmem_long_filter(line)
{
	#eg:ffffe2fb42773400
	#eg: 10    4096k  ffff8feadffd2430
	if (match(line, ": kmem -F\\]$")) {
		allow_regx="^\\s*[a-f0-9]+|^\\s*[0-9]+ ";
		next;
	}

	#eg:ffffe2fb40000280     a000                0        0  1 7ffffc0000800 reserved
	if (match(line, ": kmem -p\\]$")) {
		allow_regx="^\\s*[a-f0-9]+ ";
		next;
	}
}