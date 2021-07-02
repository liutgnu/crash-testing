# irq
function irq_filter(line)
{
	#eg: 23   ffff97587e9bb000  ffff97587f467600  "uhci_hcd:usb3"
	#eg:                        ffff97587ea16e80  "radeon"
	if (match(line, ": irq\\]$")) {
		allow_regx="^\\s*[0-9]+ |^\\s*[0-9a-f]+ ";
		next;
	}

	#eg:[195] irq_entries_start+1304
	if (match(line, ": irq -d\\]$")) {
		allow_regx="^\\s*\\[[0-9 ]+\\] ";
		next;
	}
	
	if (match(line, ": irq -b\\]$")) {
		allow_regx="^\\s*\\[[0-9 ]+\\] ";
		next;
	}

	#eg: 78 ens7f0-TxRx-7        5
	if (match(line, ": irq -a\\]$")) {
		allow_regx="^\\s*[0-9 ]+ ";
		next;
	}
	
	#eg:231:          0          0 
	if (match(line, ": irq -s\\]$")) {
		allow_regx="^\\s*[0-9]+: ";
		next;
	}
}