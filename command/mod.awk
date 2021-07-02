# mod
function mod_filter(line)
{
	#eg:ffffffffc0906bc0  nfs                    ffffffffc08cd000   315392  (not loaded)  [CONFIG_KALLSYMS]
	if (match(line, ": mod\\]$")) {
		allow_regx="^\\s*[a-f0-9]+ +[a-z0-9_]+";
		next;
	}

	if (match(line, ": mod -r\\]$")) {
		allow_regx="^\\s*[a-f0-9]+ +[a-z0-9_]+";
		next;
	}

	if (match(line, ": mod -R\\]$")) {
		allow_regx="^\\s*[a-f0-9]+ +[a-z0-9_]+";
		next;
	}

	if (match(line, ": mod -g\\]$")) {
		allow_regx="^\\s*[a-f0-9]+ +[a-z0-9_]+";
		next;
	}

	if (match(line, ": mod -t\\]$")) {
		next;
	}

	if (match(line, ": mod -S\\]$")) {
		allow_regx="cannot find or load object file for";
		next;
	}
}