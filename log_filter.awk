@include "alias.awk"
@include "ascii.awk"
@include "bpf.awk"
@include "bt.awk"
@include "dev.awk"
@include "dis.awk"
@include "files.awk"
@include "files_long.awk"
@include "fuser.awk"
@include "help.awk"
@include "ipcs.awk"
@include "irq.awk"
@include "kmem.awk"
@include "kmem_long.awk"
@include "log.awk"
@include "mach.awk"
@include "mod.awk"
@include "mount.awk"
@include "net.awk"
@include "net_long.awk"
@include "p.awk"
@include "ps.awk"
@include "pte.awk"
@include "ptov.awk"
@include "rd.awk"
@include "runq.awk"
@include "set.awk"
@include "sig.awk"
@include "swap.awk"
@include "sym.awk"
@include "sym_long.awk"
@include "sys.awk"
@include "task.awk"
@include "timer.awk"
@include "vm.awk"
@include "vm_long.awk"
@include "whatis.awk"

NR==1                       {allow_regx="/\\//\\\\\\/";deny_regx="/\\//\\\\\\/";}
/\[Command /                {flag=$5;allow_regx="/\\//\\\\\\/";deny_regx="/\\//\\\\\\/";title=$0"\n"}
/\[Test 1]/                 {print $0;allow_regx="/\\//\\\\\\/";deny_regx="/\\//\\\\\\/";title="";next;}
/\[Test /                   {printf("\n%s\n",$0);allow_regx="/\\//\\\\\\/";deny_regx="/\\//\\\\\\/";title="";next;}
/\[Dumpfile /               {n=2;}
n > 0 && n-- >0             {print $0;next;}

# For fatal errors
tolower($0) ~ /segmentation fault/    {printf("%s%s\n",title,$0);title="";next;}
tolower($0) ~ /permission denied/     {printf("%s%s\n",title,$0);title="";next;}
/do not match!/                       {printf("%s%s\n",title,$0);title="";next;}
/malformed ELF file:/                 {printf("%s%s\n",title,$0);title="";next;}

###########################################################
#        Now we deal with specific test cases             #
###########################################################
flag=="alias" 		{alias_filter($0);}
flag=="ascii" 		{ascii_filter($0);}
flag=="bpf" 		{bpf_filter($0);}
flag=="bt" || flag=="foreach" {bt_filter($0);}
flag=="dev" 		{dev_filter($0);}
flag=="dis" 		{dis_filter($0);}
flag=="files" 		{files_filter($0);}
flag=="files" || flag=="foreach" {files_long_filter($0);}
flag=="fuser" 		{fuser_filter($0);}
flag=="help" 		{help_filter($0);}
flag=="ipcs" 		{ipcs_filter($0);}
flag=="irq" 		{irq_filter($0);}
flag=="kmem" 		{kmem_filter($0);}
flag=="kmem" 		{kmem_long_filter($0);}
flag=="log" 		{log_filter($0);}
flag=="mach" 		{mach_filter($0);}
flag=="mod" 		{mod_filter($0);}
flag=="mount" 		{mount_filter($0);}
flag=="net" 		{net_filter($0);}
flag=="net" || flag=="foreach" {net_long_filter($0);}
flag=="p" 		{p_filter($0);}
flag=="ps" 		{ps_filter($0);}
flag=="pte" 		{pte_filter($0);}
flag=="ptov" 		{ptov_filter($0);}
flag=="rd" 		{rd_filter($0);}
flag=="runq" 		{runq_filter($0);}
flag=="set" 		{set_filter($0);}
flag=="sig" 		{sig_filter($0);}
flag=="swap" 		{swap_filter($0);}
flag=="sym" 		{sym_filter($0);}
flag=="sym" 		{sym_long_filter($0);}
flag=="sys" 		{sys_filter($0);}
flag=="task" 		{task_filter($0);}
flag=="timer" 		{timer_filter($0);}
flag=="vm"		{vm_filter($0);}
flag=="vm" 		{vm_long_filter($0);}
flag=="whatis" 		{whatis_filter($0);}

$0 ~ deny_regx                        {printf("%s%s\n",title,$0);title="";next;}
$0 ~ allow_regx                       {next;}
###########################################################
#              End of specific test cases                 #
###########################################################

# For logs filtered by allow_regx, check if contains the keywords
tolower($0) ~ /\<mismatch\>/          {printf("%s%s\n",title,$0);title="";next;}
tolower($0) ~ /cannot/                {printf("%s%s\n",title,$0);title="";next;}
tolower($0) ~ /\<fail\>/              {printf("%s%s\n",title,$0);title="";next;}
tolower($0) ~ /\<failed\>/            {printf("%s%s\n",title,$0);title="";next;}
tolower($0) ~ /\<error\>/             {printf("%s%s\n",title,$0);title="";next;}
tolower($0) ~ /\<invalid\>/           {printf("%s%s\n",title,$0);title="";next;}
tolower($0) ~ /unexpect/              {printf("%s%s\n",title,$0);title="";next;}
tolower($0) ~ /not supported/         {printf("%s%s\n",title,$0);title="";next;}
tolower($0) ~ /no such file or directory/        {printf("%s%s\n",title,$0);title="";next;}
/Exit values mismatch/                {print $0;next;}
/Exit values are not 0/               {print $0;next;}
/Crash returned with/                 {print $0;next;}