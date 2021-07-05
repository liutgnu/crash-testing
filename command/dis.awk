#dis
function dis_filter(line)
{
	#eg:0xffffffff8c208b42 <schedule+18>:	test   %rdx,%rdx
	if (match(line, ": dis schedule\\]$")) {
		allow_regx="^[0-9a-fx]+ <schedule(\\+[0-9]+)?>:";
		next;
	}

	#eg:/usr/src/debug/kernel-4.18.0-3/./include/linux/list.h: 203
	if (match(line, ": dis -l schedule\\]$")) {
		allow_regx="^[0-9a-fx]+ <schedule(\\+[0-9]+)?>:";
		allow_regx=allow_regx "|: [0-9]+";
		next;
	}

	#eg:    275  if (dentry->d_op && dentry->d_op->d_iput)
	#eg:  * 276      dentry->d_op->d_iput(dentry, inode);
	if (match(line, ": dis -s schedule\\]$")) {
		allow_regx="^\\s*(\\*)?\\s*[0-9]+ ";
		next;
	}
}