#pte
function pte_filter(line)
{
	if (match(line, ": pte 1\\]$")) {
		next;
	}
}