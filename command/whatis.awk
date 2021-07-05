# whatis
function whatis_filter(line)
{
	if (match(line, ": whatis linux_banner\\]$")) {
		allow_regx="^\\s*const char linux_banner";
		allow_regx=allow_regx "|WARNING: malloc/free mismatch";
		next;
	}
}