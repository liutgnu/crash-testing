# kmem
function kmem_filter(line)
{
	#eg: 10    4096k  ffff8feadffd2fc0       0      0
	if (match(line, ": kmem -f\\]$")) {
		allow_regx="^\\s*[0-9]+ ";
		next;
	}

	if (match(line, ": kmem -c\\]$")) {
		allow_regx="option not supported or applicable on this architecture or kernel";
		next;
	}

	if (match(line, ": kmem -C\\]$")) {
		allow_regx="option not supported or applicable on this architecture or kernel";
		next;
	}

	#eg:   COMMITTED    95427     372.8 MB    6% of TOTAL LIMIT
	if (match(line, ": kmem -i\\]$")) {
		allow_regx="^\\s*[A-Z ]+ ";
		next;
	}

	#eg:ffff8feac7d0aba0  ffff8feac7d08800  ffffb57d80000000 - ffffb57d80002000     8192
	if (match(line, ": kmem -v\\]$")) {
		allow_regx="^\\s*[a-f0-9]+ ";
		next;
	}

	#eg:          NR_ZONE_INACTIVE_ANON: 9816
	if (match(line, ": kmem -V\\]$")) {
		allow_regx="^\\s*[A-Z_]+:";
		next;
	}

	if (match(line, ": kmem -z\\]$")) {
		allow_regx="^\\s*[A-Z_]+:";
		next;
	}

	#eg:27  ffff8feadff4c1b0  ffffe2fb40000000  ffffe2fb43600000   PMO  884736
	#eg: ffff8feadbb40800   memory3    18000000 - 1fffffff  0    ONLINE  3
	if (match(line, ": kmem -n\\]$")) {
		allow_regx="^\\s*[0-9]+ ";
		allow_regx=allow_regx "|^\\s*[a-f0-9]+ ";
		next;
	}

	#eg:  CPU 0: ffff8feadba00000
	if (match(line, ": kmem -o\\]$")) {
		allow_regx="^\\s*[0-9 A-Z]+:";
		next;
	}

	#eg:ffffffff8b1d8ae0    2MB       0       0  hugepages-2048kB
	if (match(line, ": kmem -h\\]$")) {
		allow_regx="^\\s*[0-9a-f]+ ";
		allow_regx=allow_regx "|option not supported or applicable on this architecture or kernel";
		next;
	}

	#eg:kmem: kmalloc-192: cannot gather relevant slab data
	#eg:kmem: xfs_buf: slab: 37202e6e900 invalid freepointer: b844bab900001d70  <-- invalid
	if (match(line, ": kmem -s\\]$")) {
		deny_regx="invalid freepointer";
		allow_regx="^\\s*[0-9a-f]+ ";
		allow_regx=allow_regx "|^\\s*kmem: ";
		next;
	}

	if (match(line, ": kmem -S TCP\\]$")) {
		deny_regx="invalid freepointer";
		allow_regx="";
		next;
	}

	#eg:ffff8feac7d44c00      256       1792      6560    410     4k  filp
	if (match(line, ": kmem -r\\]$")) {
		allow_regx="^\\s*[0-9a-f]+ ";
		allow_regx=allow_regx "|^\\s*kmem: ";
		allow_regx=allow_regx "|option not supported or applicable on this architecture or kernel";
		next;
	}

	#eg:PG_savepinned     4  0000010
	if (match(line, ": kmem -g\\]$")) {
		allow_regx="^\\s*[a-zA-Z_0-9]+ ";
		next;
	}
}