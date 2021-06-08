#!/bin/bash

function live_test_filter()
{
    # In live testing, source code of crash-testing will be included in ENV of
    # some process, and ps -a will output the ENV of process, then filtered by
    # log_filter.
    # That is, the source code of log_filter.sh will be filtered by log_filter,
    # which is annoying. So we will strip the output of "ps -a" and similar
    # commands.

    # awk doesn't support look-ahead, so difficult to make regx for "deny all",
    # so we use a strange pattern for "deny all".
    awk -v LIVE_FLAG="$1" -F '[: \\[\\]]' '
        /^\[Dumpfile /              {allow_regx=".*";if($3=="live"){is_live="yes"}else{is_live="no"};print $0;next;}
        (is_live=="yes" || LIVE_FLAG=="yes") && /: ps -a\]$/ {allow_regx="/\\//\\\\\\/";print $0;next;}
        /^\[Command /               {allow_regx=".*";print $0;next;}
        
        $0 ~ allow_regx             {print $0;}
    '
}

# Please update the awk regex rules if it cannot identify error logs correctly.
function log_filter()
{
    awk -F '[: \\[\\]]' '
        # reset allow_regx to none-shall-pass for cases when:
        # 1) First line of the log;
        # 2) Meet [Test xx], which indicates new start of the next test.
        # 3) Meet [Command xx], which indicates new allow_regx will come, so
        #       we clear it first.
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
        #alias
        #eg:builtin  man      help
        flag=="alias" && /: alias\]$/          {allow_regx="builtin ";next;}

        #ascii

        #bpf
        #eg: 13  ffffa4c10c569000 ffff9837fddf8d00  CGROUP_SKB   7be49e3934a125ba   13,14  
        flag=="bpf" && /: bpf\]$/              {allow_regx="command not supported or applicable on this architecture or kernel|^\\s*[0-9 ]+";next;}
        #eg: 13  ffffa4c10c569000 ffff9837fddf8d00  CGROUP_SKB   7be49e3934a125ba   13,14   
        #eg:     XLATED: 296  JITED: 229  MEMLOCK: 4096
        #eg:     LOAD_TIME: Thu Feb 25 04:47:20 2021
        flag=="bpf" && /: bpf -PM\]$/          {allow_regx="command not supported or applicable on this architecture or kernel|^\\s*[A-Z_0-9]+:|^\\s*[0-9]+ ";next;}
        #eg:  ops = 0xffffffff8c835a80, 
        #eg:  inner_map_meta = 0x0, 
        #eg:  0xffffffffc03c0ee2:	push   %rbp
        flag=="bpf" && /: bpf -PM -jTs\]$/     {allow_regx="command not supported or applicable on this architecture or kernel|^\\s*[A-Z_0-9]+:|^\\s*[0-9]+ |^\\s*[0-9a-fA-FxX]+:|^\\s*[a-zA-Z0-9_ ]+=";next;}

        #bt
        #eg:PID: 0      TASK: ffffffff8cc10740  CPU: 0   COMMAND: "swapper/0"
        #eg:  #0 [fffffe0000008a10] machine_kexec at ffffffff8ba5176e
        #eg:--- <NMI exception stack> ---
        #eg:    R13: 0000000000000003  R14: ffffffff8c899170  R15: ffff97587d15fb45
        flag=="bt" && /: bt\]$/                {allow_regx="[A-Z0-9_]+: |\\[[a-f0-9]+\\] |---";next;}
        flag=="bt" && /: bt -a\]$/             {allow_regx="[A-Z0-9_]+: |\\[[a-f0-9]+\\] |---|option not supported on a live system or live dump|cannot be determined: try -t or -T options";next;}
        flag=="bt" && /: bt -c 0\]$/           {allow_regx="[A-Z0-9_]+: |\\[[a-f0-9]+\\] |---|option not supported on a live system or live dump|cannot be determined: try -t or -T options";next;}
        flag=="bt" && /: bt -g\]$/             {allow_regx="[A-Z0-9_]+: |\\[[a-f0-9]+\\] |---";next;}
        #eg:ffffffff8cc03f60:  0000000000000000 0000000000000000
        flag=="bt" && /: bt -r\]$/             {allow_regx="[A-Z0-9_]+: |^[a-f0-9]+: ";next;}
        flag=="bt" && /: bt -t\]$/             {allow_regx="[A-Z0-9_]+: |\\[[a-f0-9]+\\] |---";next;}
        flag=="bt" && /: bt -T\]$/             {allow_regx="[A-Z0-9_]+: |\\[[a-f0-9]+\\]";next;}
        #eg:    /usr/src/debug/kernel-4.18.0-3/arch/x86/kernel/machine_kexec_64.c: 339
        flag=="bt" && /: bt -l\]$/             {allow_regx="[A-Z0-9_]+: |\\[[a-f0-9]+\\] |---|: [0-9]+";next;}
        flag=="bt" && /: bt -e\]$/             {allow_regx="[A-Z0-9_]+: |option not supported or applicable on this architecture or kernel";next;}
        #eg:CPU 124 DEBUG EXCEPTION STACK:
        flag=="bt" && /: bt -E\]$/             {allow_regx="[A-Z0-9_]+: |[A-Z0-9_]+:$|option not supported or applicable on this architecture or kernel";next;}
        flag=="bt" && /: bt -f\]$/             {allow_regx="[a-f0-9]+: |\\[[a-f0-9]+\\] |---|[A-Z0-9_]+: ";next;}
        flag=="bt" && /: bt -F\]$/             {allow_regx="[a-f0-9]+: |\\[[a-f0-9]+\\] |---|[A-Z0-9_]+: ";next;}
        flag=="bt" && /: bt -FF\]$/            {allow_regx="[a-f0-9]+: |\\[[a-f0-9]+\\] |---|[A-Z0-9_]+: ";next;}
        flag=="bt" && /: bt -o\]$/             {allow_regx="\\[[a-f0-9]+\\] |---|[A-Z0-9_]+: |option not supported or applicable on this architecture or kernel";next;}
        flag=="bt" && /: bt -v\]$/             {allow_regx="possible stack overflow: |bt: invalid kernel virtual address: 0|option not supported or applicable on this architecture or kernel";next;}
        flag=="bt" && /: bt -p\]$/             {allow_regx="\\[[a-f0-9]+\\] |---|[A-Z0-9_]+: |option not supported on a live system or live dump";next;}
        flag=="bt" && /: bt -s\]$/             {allow_regx="\\[[a-f0-9]+\\] |---|[A-Z0-9_]+: ";next;}
        flag=="bt" && /: bt -sx\]$/            {allow_regx="\\[[a-f0-9]+\\] |---|[A-Z0-9_]+: ";next;}
        flag=="foreach" && /: foreach bt\]$/   {allow_regx="\\[[a-f0-9]+\\] |---|[A-Z0-9_]+: |cannot be determined: try -t or -T options";next;}

        #dev
        #eg:   4      tty            ffff978845f6f200  tty_fops
        flag=="dev" && /: dev\]$/              {allow_regx="^\\s*[0-9]+ ";next;}
        #eg:ffff97587e91d3c0  4000-40ff  hpsa
        flag=="dev" && /: dev -i\]$/           {allow_regx="^\\[[a-f0-9]+ \\]";next;}
        #eg:  ffff97d7ffaf1000 0000:05:00.0  0200  8086:10fb  ENDPOINT 
        flag=="dev" && /: dev -p\]$/           {allow_regx="^[a-f0-9]+ |option not supported or applicable on this architecture or kernel";next;}
        #eg:  71 ffff980845f1a800   sdnt       ffff97b7f4e7cd80       1     0     1     1
        flag=="dev" && /: dev -d\]$/           {allow_regx="^\\s*[0-9 ]+[a-f0-9]+ ";next;}
        flag=="dev" && /: dev -D\]$/           {allow_regx="^\\s*[0-9 ]+[a-f0-9]+ ";next;}
        #eg:  1    0x2001240          33558464         cxgb4_0000:03:00.4
        flag=="dev" && /: dev -V\]$/           {allow_regx="^\\s*[0-9]+ |dev: -V option not supported on this dumpfile type|dev: -V option not supported on a live system";next;}

        #dis
        #eg:0xffffffff8c208b42 <schedule+18>:	test   %rdx,%rdx
        flag=="dis" && /: dis schedule\]$/     {allow_regx="^[0-9a-fx]+ <schedule(\\+[0-9]+)?>:";next;}
        #eg:/usr/src/debug/kernel-4.18.0-3/./include/linux/list.h: 203
        flag=="dis" && /: dis -l schedule\]$/  {allow_regx="^[0-9a-fx]+ <schedule(\\+[0-9]+)?>:|: [0-9]+";next;}
        #eg:    275  if (dentry->d_op && dentry->d_op->d_iput)
        #eg:  * 276      dentry->d_op->d_iput(dentry, inode);
        flag=="dis" && /: dis -s schedule\]$/  {allow_regx="^\\s*(\\*)?\\s*[0-9]+ ";next;}
        
        #files
        #eg:  0  c6b9c740  c7cc45a0  c7c939e0  CHR   /dev/null
        flag=="files" && /: files\]$/          {allow_regx="^\\s*[0-9]+\\s+[0-9a-f]+";next;}
        flag=="files" && /: files -c\]$/       {allow_regx="^\\s*[0-9]+\\s+[0-9a-f]+";next;}

        #files_long
        flag=="foreach" && /: foreach files\]$/  {allow_regx="^\\s*[0-9]+\\s+[0-9a-f]+";next;}

        #fuser
        #eg: 4706  ffff9817f02b15c0  "kworker/55:2"   root cwd
        flag=="fuser" && /: fuser \/\]$/       {allow_regx="^\\s*[0-9]+\\s+[0-9a-f]+";next;}

        #help
        flag=="help" && /: help\]$/            {allow_regx=".*";next;}
        #eg:    args[1]: 55bc3acb8c37: scroll
        flag=="help" && /: help -a\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";next;}
        flag=="help" && /: help -b\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";next;}
        flag=="help" && /: help -B\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";next;}
        flag=="help" && /: help -c\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";next;}
        flag=="help" && /: help -d\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";next;}
        #eg:   OFFSET(printk_ringbuffer.fail)=72
        #eg:   Item error[1][0] => position=0x22449c56f size=0x1: 01
        flag=="help" && /: help -D\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:|^\\s*[A-Z]+\\([a-zA-Z_0-9\\.]+\\)=|error(\\[[0-9]+\\])+\\s+=>";next;}
        flag=="help" && /: help -e\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";next;}
        flag=="help" && /: help -f\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";next;}
        flag=="help" && /: help -g\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";next;}
        flag=="help" && /: help -h\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";next;}
        flag=="help" && /: help -H\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";next;}
        flag=="help" && /: help -k\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";next;}
        flag=="help" && /: help -K\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";next;}
        flag=="help" && /: help -L\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";next;}
        flag=="help" && /: help -m\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";next;}
        flag=="help" && /: help -n\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:|^\\s*[A-Z]+\\([a-zA-Z_0-9\\.]+\\)=|error(\\[[0-9]+\\])+\\s+=>";next;}
        flag=="help" && /: help -N\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";next;}
        flag=="help" && /: help -o\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";next;}
        flag=="help" && /: help -p\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";next;}
        flag=="help" && /: help -r\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";next;}
        flag=="help" && /: help -s\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";next;}
        flag=="help" && /: help -t\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";next;}
        #eg:[1979] ffff9837f2e30000 (chronyd)
        flag=="help" && /: help -T\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:|^\\s*\\[[ 0-9]+\\]\\s*[a-z0-9]+";next;}
        flag=="help" && /: help -v\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:|^\\s*\\[[ 0-9]+\\]\\s*[a-z0-9]+";next;}
        flag=="help" && /: help -V\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:|^\\s*\\[[ 0-9]+\\]\\s*[a-z0-9]+";next;}
        flag=="help" && /: help -x\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:|^\\s*\\[[ 0-9]+\\]\\s*[a-z0-9]+";next;}
        #eg: -x - text cache
        flag=="help" && /: help -z\]$/         {allow_regx="^\\s*-[a-zA-Z]\\s*-";next;}

        # ipcs
        #eg:ffff880473a28490 00000001 32769      0     666   90000      1
        flag=="ipcs" && /: ipcs\]$/            {allow_regx="^\\s*[a-f0-9]+ ";next;}
        #eg:PAGES ALLOCATED/RESIDENT/SWAPPED: 22/1/0
        flag=="ipcs" && /: ipcs -M\]$/         {allow_regx="^\\s*[a-zA-Z _\\[\\]0-9\\./]+:";next;}

        # irq
        #eg: 23   ffff97587e9bb000  ffff97587f467600  "uhci_hcd:usb3"
        #eg:                        ffff97587ea16e80  "radeon"
        flag=="irq" && /: irq\]$/              {allow_regx="^\\s*[0-9]+ |^\\s*[0-9a-f]+ ";next;}
        #eg:[195] irq_entries_start+1304
        flag=="irq" && /: irq -d\]$/           {allow_regx="^\\s*\\[[0-9 ]+\\] ";next;}
        flag=="irq" && /: irq -b\]$/           {allow_regx="^\\s*\\[[0-9 ]+\\] ";next;}
        #eg: 78 ens7f0-TxRx-7        5
        flag=="irq" && /: irq -a\]$/           {allow_regx="^\\s*[0-9 ]+ ";next;}
        #eg:231:          0          0 
        flag=="irq" && /: irq -s\]$/           {allow_regx="^\\s*[0-9]+: ";next;}

        # kmem
        #eg: 10    4096k  ffff8feadffd2fc0       0      0
        flag=="kmem" && /: kmem -f\]$/         {allow_regx="^\\s*[0-9]+ ";next;}
        flag=="kmem" && /: kmem -c\]$/         {allow_regx="option not supported or applicable on this architecture or kernel";next;}
        flag=="kmem" && /: kmem -C\]$/         {allow_regx="option not supported or applicable on this architecture or kernel";next;}
        #eg:   COMMITTED    95427     372.8 MB    6% of TOTAL LIMIT
        flag=="kmem" && /: kmem -i\]$/         {allow_regx="^\\s*[A-Z ]+ ";next;}
        #eg:ffff8feac7d0aba0  ffff8feac7d08800  ffffb57d80000000 - ffffb57d80002000     8192
        flag=="kmem" && /: kmem -v\]$/         {allow_regx="^\\s*[a-f0-9]+ ";next;}
        #eg:          NR_ZONE_INACTIVE_ANON: 9816
        flag=="kmem" && /: kmem -V\]$/         {allow_regx="^\\s*[A-Z_]+:";next;}
        flag=="kmem" && /: kmem -z\]$/         {allow_regx="^\\s*[A-Z_]+:";next;}
        #eg:27  ffff8feadff4c1b0  ffffe2fb40000000  ffffe2fb43600000   PMO  884736
        #eg: ffff8feadbb40800   memory3    18000000 - 1fffffff  0    ONLINE  3
        flag=="kmem" && /: kmem -n\]$/         {allow_regx="^\\s*[0-9]+ |^\\s*[a-f0-9]+ ";next;}
        #eg:  CPU 0: ffff8feadba00000
        flag=="kmem" && /: kmem -o\]$/         {allow_regx="^\\s*[0-9 A-Z]+:";next;}
        #eg:ffffffff8b1d8ae0    2MB       0       0  hugepages-2048kB
        flag=="kmem" && /: kmem -h\]$/         {allow_regx="^\\s*[0-9a-f]+ |option not supported or applicable on this architecture or kernel";next;}
        #eg:kmem: kmalloc-192: cannot gather relevant slab data
        #eg:kmem: xfs_buf: slab: 37202e6e900 invalid freepointer: b844bab900001d70  <-- invalid
        flag=="kmem" && /: kmem -s\]$/         {deny_regx="invalid freepointer";allow_regx="^\\s*[0-9a-f]+ |^\\s*kmem: ";next;}
        flag=="kmem" && /: kmem -S TCP\]$/     {deny_regx="invalid freepointer";allow_regx="";next;}
        #eg:ffff8feac7d44c00      256       1792      6560    410     4k  filp
        flag=="kmem" && /: kmem -r\]$/         {allow_regx="^\\s*[0-9a-f]+ |^\\s*kmem: |option not supported or applicable on this architecture or kernel";next;}
        #eg:PG_savepinned     4  0000010
        flag=="kmem" && /: kmem -g\]$/         {allow_regx="^\\s*[a-zA-Z_0-9]+ ";next;}

        # kmem_long
        #eg:ffffe2fb42773400
        #eg: 10    4096k  ffff8feadffd2430
        flag=="kmem" && /: kmem -F\]$/         {allow_regx="^\\s*[a-f0-9]+|^\\s*[0-9]+ ";next;}
        #eg:ffffe2fb40000280     a000                0        0  1 7ffffc0000800 reserved
        flag=="kmem" && /: kmem -p\]$/         {allow_regx="^\\s*[a-f0-9]+ ";next;}

        # log
        flag=="log" && /: log\]$/              {allow_regx=".*";next;}
        flag=="log" && /: log -T\]$/           {allow_regx="option not supported or applicable on this architecture or kernel|^\\[.+[0-2][0-9]:[0-5][0-9]:[0-5][0-9].+\\]";next;}
        flag=="log" && /: log -t\]$/           {allow_regx=".*";next;}
        flag=="log" && /: log -d\]$/           {allow_regx="option not supported or applicable on this architecture or kernel|^\\[\\s*[0-9]+\\.[0-9]+\\]";next;}
        #eg:[   11.036522] <6>scsi 1:0:0:0: alua: rtpg failed with 8000002
        #eg:<6>scsi 1:0:0:0: alua: rtpg failed with 8000002
        flag=="log" && /: log -m\]$/           {allow_regx="^\\s*(\\[\\s*[0-9]+\\.[0-9]+\\] )?<[0-7]>";next;}
        flag=="log" && /: log -a\]$/           {allow_regx="^type=[0-9]+ audit\\(|option not supported or applicable on this architecture or kernel";next;}

        # mach
        #eg:          MACHINE TYPE: x86_64
        flag=="mach" && /: mach\]$/            {allow_regx="^\\s*[A-Z 0-9]+:";next;}
        #eg:    000000001ff75000 - 000000001ff77000  E820_NVS
        flag=="mach" && /: mach -m\]$/         {allow_regx="^\\s*[a-f0-9]+ - [a-f0-9]+";next;}
        #eg:  x86_clflush_size = 64,
        flag=="mach" && /: mach -c\]$/         {allow_regx="^\\s*[A-Za-z0-9_]+ =";next;}

        # mod
        #eg:ffffffffc0906bc0  nfs                    ffffffffc08cd000   315392  (not loaded)  [CONFIG_KALLSYMS]
        flag=="mod" && /: mod\]$/              {allow_regx="^\\s*[a-f0-9]+ +[a-z0-9_]+";next;}
        flag=="mod" && /: mod -r\]$/           {allow_regx="^\\s*[a-f0-9]+ +[a-z0-9_]+";next;}
        flag=="mod" && /: mod -R\]$/           {allow_regx="^\\s*[a-f0-9]+ +[a-z0-9_]+";next;}
        flag=="mod" && /: mod -g\]$/           {allow_regx="^\\s*[a-f0-9]+ +[a-z0-9_]+";next;}
        flag=="mod" && /: mod -t\]$/           {next;}
        flag=="mod" && /: mod -S\]$/           {allow_regx="cannot find or load object file for";next;}

        # mount
        #eg:ffff8feadbb36a80 ffff8feac7c0c800 proc   proc      /proc
        flag=="mount" && /: mount\]$/          {allow_regx="^\\s*[a-f0-9]+ +[a-f0-9]+ ";next;}
        #eg:c6d02000  c6d0fc20  REG   usr/X11R6/lib/libICE.so.6.3
        flag=="mount" && /: mount -f\]$/       {allow_regx="option not supported or applicable on this architecture or kernel|^\\s*[a-f0-9]+ +[a-f0-9]+ ";next;}
        #eg:c72c4008
        flag=="mount" && /: mount -i\]$/       {allow_regx="option not supported or applicable on this architecture or kernel|^\\s*[a-f0-9]+";next;}

        # net
        flag=="net" && /: net\]$/              {allow_regx="^\\s*[a-f0-9]+ +[a-z0-9]+";next;}
        #eg:ffff8fead9ac9200 0.0.0.0         UNKNOWN    00 00 00 00 00 00  lo      NOARP
        flag=="net" && /: net -a\]$/           {allow_regx="^\\s*[a-f0-9]+ [0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+";next;}
        #eg:104 ffff8feada20a940 ffff8feada8d8000 INET6:STREAM
        flag=="net" && /: net -s 1\]$/         {allow_regx="^\\s*[0-9]+ +[a-f0-9]+ +[a-f0-9]+";next;}

        # net_long
        #eg:      skc_ipv6only = 0 , 
        flag=="net" && /: net -S\]$/           {allow_regx="^\\s*[a-z0-9_]+ =";next;}
        flag=="foreach" && /: foreach net -s\]$/ {allow_regx="^\\s*PID: |^\\s*[0-9]+\\s+[0-9a-f]+\\s+[0-9a-f]+";next;}

        # p
        flag=="p" && /: p linux_banner\]$/     {allow_regx="^\\s*linux_banner =";next;}

        # ps
        #eg:> 20688  20687   1  ffff8feac033ab80  RU   0.1   25384   4020  bash
        flag=="ps" && /: ps\]$/                {allow_regx="^\\s*>?\\s*[0-9]+\\s*[0-9]+\\s*[0-9]+\\s*[0-9a-f]+";next;}
        flag=="ps" && /: ps -k\]$/             {allow_regx="^\\s*>?\\s*[0-9]+\\s*[0-9]+\\s*[0-9]+\\s*[0-9a-f]+";next;}
        flag=="ps" && /: ps -u\]$/             {allow_regx="^\\s*>?\\s*[0-9]+\\s*[0-9]+\\s*[0-9]+\\s*[0-9a-f]+";next;}
        flag=="ps" && /: ps -G\]$/             {allow_regx="^\\s*>?\\s*[0-9]+\\s*[0-9]+\\s*[0-9]+\\s*[0-9a-f]+";next;}
        flag=="ps" && /: ps -s\]$/             {allow_regx="^\\s*>?\\s*[0-9]+\\s*[0-9]+\\s*[0-9]+\\s*[0-9a-f]+";next;}
        flag=="ps" && /: ps -A\]$/             {allow_regx="^\\s*>?\\s*[0-9]+\\s*[0-9]+\\s*[0-9]+\\s*[0-9a-f]+";next;}
        #eg: PID: 2      TASK: ffff8feac7785700  CPU: 1   COMMAND: "kthreadd"
        flag=="ps" && /: ps -p\]$/             {allow_regx="^\\s*PID: [0-9]+\\s+TASK: ";next;}
        flag=="ps" && /: ps -c\]$/             {allow_regx="^\\s*PID: [0-9]+\\s+TASK: ";next;}
        #eg:  START TIME: 34000000
        #eg:PID: 706    TASK: ffff8800497a8340  CPU: 1   COMMAND: "logical error i"
        flag=="ps" && /: ps -t\]$/             {allow_regx="^\\s*[A-Z ]: |^\\s*PID: ";next;}
        #eg:[68067836650436] [IN]  PID: 17481  TASK: ffff8fead750d700  CPU: 0   COMMAND: "sleep"
        flag=="ps" && /: ps -l\]$/             {allow_regx="^\\s*\\[[0-9 ]+\\] +\\[[A-Z]+\\]";next;}
        #eg:[0 00:00:07.698] [IN]  PID: 698    TASK: ffff8fead8fd2b80  CPU: 1   COMMAND: "sssd"
        flag=="ps" && /: ps -m\]$/             {allow_regx="^\\s*\\[[0-9 :.]+\\] +\\[[A-Z]+\\]";next;}
        flag=="ps" && /: ps -m -C 0\]$/        {allow_regx="^\\s*\\[[0-9 :.]+\\] +\\[[A-Z]+\\]";next;}
        #eg:PID: 1      TASK: ffff8feac7784140  CPU: 0   COMMAND: "systemd"
        #eg:ARG: /usr/local/Tivoli/fusa/ep/bin/linux-ix86/JRE/DMAE/bin/exe/java
        #eg:ENV:      HAL_PROP_INFO_CAPABILITIES=cpufreq_control
        flag=="ps" && /: ps -a\]$/             {allow_regx="^\\s*PID: [0-9]+\\s+TASK: |^\\s*(ENV:)?\\s*[A-Z_0-9]+=|^\\s*ARG: |ps: cannot access user stack address:";next;}
        flag=="ps" && /: ps -g\]$/             {allow_regx="^\\s*PID: [0-9]+\\s+TASK: ";next;}
        #eg:         CPU   (unlimited)   (unlimited)
        flag=="ps" && /: ps -r\]$/             {allow_regx="^\\s*[A-Z]+";next;}
        #eg:  IN: 87
        flag=="ps" && /: ps -S\]$/             {allow_regx="^\\s*[A-Z]+: [0-9]+";next;}

        #pte
        flag=="pte" && /: pte 1\]$/            {next;}

        #ptov
        #eg: ffff8fe9c0000000  0
        flag=="ptov" && /: ptov 0\]$/          {allow_regx="^\\s*[0-9a-f]+\\s+[0-9a-f]+";next;}

        #rd
        #eg:ffffffff8a400100:  4c 69 6e 75 78 20 76 65 72 73 69 6f 6e 20 34 2e   Linux version 4.
        flag=="rd" && /: rd -8 linux_banner 256\]$/    {allow_regx="^\\s*[0-9a-f]+:  ([0-9a-f]{2} ){16}";next;}

        #runq
        #eg:CPU 1 RUNQUEUE: ffff8feadbb22900
        flag=="runq" && /: runq\]$/            {allow_regx="^\\s*[A-Z 0-9_]+:";next;}
        #eg:CPU 0: 2680990637359
        #eg:       2680986653330  PID: 28228  TASK: ffff880037ca2ac0  COMMAND: "loop"
        flag=="runq" && /: runq -t\]$/         {allow_regx="^\\s*CPU [0-9]+: |^\\s*[0-9]+\\s+PID: ";next;}
        #eg:  CPU 0: 0.00 secs
        flag=="runq" && /: runq -T\]$/         {allow_regx="^\\s*CPU [0-9]+:\\s+[0-9]+.[0-9]+";next;}
        #eg: CPU 1: [0 00:00:00.000]  PID: 20688  TASK: ffff8feac033ab80  COMMAND: "bash"
        flag=="runq" && /: runq -m\]$/         {allow_regx="^\\s*CPU [0-9]+:\\s+\\[";next;}
        flag=="runq" && /: runq -g\]$/         {allow_regx="^\\s*[A-Z_ ]+:|^\\s*\\[[0-9 ]+\\] PID:|option not supported or applicable on this architecture or kernel";next;}
        #eg:CPU 0 RUNQUEUE: ffff8feadba22900
        flag=="runq" && /: runq -c 0\]$/       {allow_regx="^\\s*[A-Z_ 0-9]+:";next;}

        # set
        flag=="set" && /: set\]$/              {allow_regx="^\\s*[A-Z_ 0-9]+:";next;}
        #eg:     null-stop: off
        flag=="set" && /: set -v\]$/           {allow_regx="^\\s*[a-z\\-_ 0-9]+:";next;}

        # sig
        #eg:[61] ffff8feacb3f2888    SIG_DFL 0000000000000000 0
        #eg:    SIGNAL: 0000000000000000
        flag=="sig" && /: sig\]$/              {allow_regx="^\\s*\\[[0-9 ]+\\]\\s+[0-9a-f]+|^\\s*[A-Z_]+:";next;}
        flag=="sig" && /: sig -g\]$/           {allow_regx="^\\s*\\[[0-9 ]+\\]\\s+[0-9a-f]+|^\\s*[A-Z_]+:";next;}
        #eg:[32] SIGRTMIN
        flag=="sig" && /: sig -l\]$/           {allow_regx="^\\s*\\[[0-9 ]+\\]\\s+[A-Z]+";next;}

        # swap
        #eg:ffff8fead7ac0000  PARTITION  4169724k     8716k     0%   -2  /dev/dm-1
        flag=="swap" && /: swap\]$/            {allow_regx="^\\s*[0-9a-f]+\\s+[A-Z_]+";next;}

        # sym
        #eg:ffffffff89e1a500 (T) schedule /usr/src/debug/kernel-4.18.0-57.el8/linux-4.18.0-57.el8.x86_64/kernel/sched/core.c: 3539
        flag=="sym" && /: sym schedule\]$/     {allow_regx="^\\s*[0-9a-f]+\\s+\\([A-Za-z]\\) ";next;}
        flag=="sym" && /: sym -p -n schedule\]$/  {allow_regx="^\\s*[0-9a-f]+\\s+\\([A-Za-z]\\) ";next;}

        # sym_long
        flag=="sym" && /: sym -l\]$/           {allow_regx="^\\s*[0-9a-f]+\\s+(\\([A-Za-z]\\)|MODULE)";next;}
        
        # sys
        flag=="sys" && /: sys\]$/              {allow_regx="^\\s*[A-Z ]+:";next;}
        flag=="sys" && /: sys -c\]$/           {allow_regx="^\\s*[0-9 ]+";next;}
        flag=="sys" && /: sys -t\]$/           {allow_regx="^\\s*[A-Z_ ]+";next;}
        flag=="sys" && /: sys -i\]$/           {allow_regx="^\\s*[A-Z_ ]+:";next;}
        #eg:# EDAC - error detection and reporting (RAS) (EXPERIMENTAL)
        flag=="sys" && /: sys config\]$/       {allow_regx="^\\s*[A-Z_0-9]+=|^\\s*# ";next;}

        # task
        #eg:    syscall_work = 0,
        flag=="task" && /: task\]$/            {allow_regx="^\\s*[a-z_]+ =";next;}
        
        # timer
        flag=="timer" && /: timer\]$/          {allow_regx="^\\s*[0-9]+\\s+[0-9]+\\s+[a-f0-9]+\\s+[a-f0-9]+|WARNING: malloc/free mismatch";next;}
        flag=="timer" && /: timer -r\]$/       {allow_regx="^\\s*[0-9]+\\s+[0-9]+\\s+[0-9]+|option not supported or applicable on this architecture or kernel|WARNING: malloc/free mismatch";next;}

        # vm
        #eg:ffff899f5e1113e8 557f53791000 557f537ca000 8000871 /root/usr/bin/bash
        flag=="vm" && /: vm\]$/                {allow_regx="^\\s*[a-f0-9]+\\s*[a-f0-9]+\\s*[a-f0-9]+|WARNING: malloc/free mismatch";next;}
        flag=="vm" && /: vm -m\]$/             {allow_regx="^\\s*[a-z_]+ =|WARNING: malloc/free mismatch";next;}

        # vm_long
        flag=="vm" && /: vm -p\]$/             {allow_regx="^\\s*[a-f0-9]+ ";next;}
        flag=="vm" && /: vm -v\]$/             {allow_regx="^\\s*[a-z_]+ =";next;}

        # whatis
        flag=="whatis" && /: whatis linux_banner\]$/  {allow_regx="^\\s*const char linux_banner|WARNING: malloc/free mismatch";next;}

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
    '
}

function format_output_for_each_crash_invoke()
{
        awk '
                /\[Test /       {n=0; array[n]=$0; next;}
                //              {array[++n]=$0; next;}
                END {
                        if (array[3] == "Crash returned with 0") {
                                printf("%s Pass\n", array[0]);
                        } else {
                                printf("%s Failed\n", array[0]);
                                for (x=1; x<=n; x++) {
                                        print array[x];
                                }
                        }
                        delete array;
                }'
}

function format_output_for_log_file()
{
        awk '
                /\[Test 1\]/ {array[0]=$0; next}
                /\[Test / {
                        if (array[3] == "Crash returned with 0") {
                                printf("%s Pass\n", array[0]);
                        } else {
                                printf("%s Failed\n", array[0]);
                                for (x=1; x<=n; x++) {
                                        print array[x];
                                }
                        }
                        delete array;
                        n=0; array[n]=$0; next;
                }
                //      {array[++n]=$0;}
                END {
                        if (array[3] == "Crash returned with 0") {
                                printf("%s Pass\n", array[0]);
                        } else {
                                printf("%s Failed\n", array[0]);
                                for (x=1; x<=n; x++) {
                                        print array[x];
                                }
                        }
                        delete array;
                }'
}

function output_summary()
{
    awk '
        BEGIN                       {total=0;pass=0;fail=0;}
        /^\[Test .*\] Pass$/        {total+=1;pass+=1;print $0;next;}
        /^\[Test .*\] Failed$/      {total+=1;fail+=1;print $0;next;}
        {print $0;next;}
        END {
            printf("\n---------Test Summary---------\n");
            printf("Total: %d tests\n",total);
            printf("Pass: %d tests\n",pass);
            printf("Fail: %d tests\n",fail);
        }'
}

# $1: logs file to be filtered
function filter_log_file()
{
        if [ -f $1 ]; then
                file $1 | grep "gzip" 2>&1 >/dev/null
                if [ $? -eq 0 ]; then
                        zcat $1 | live_test_filter | log_filter | uniq | format_output_for_log_file | output_summary
                else
                        cat $1 | live_test_filter| log_filter | uniq | format_output_for_log_file | output_summary
                fi
        fi
}