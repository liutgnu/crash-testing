# crash-testing


## Todo List:
### -test for backward-compatibility, which will accepts many dumpfiles and do sanity checks
#### Currently the script can accept a list of dumpfiles and record the output of crash by iterate over the list.
### -test for patch review, which compares the outputs of the current crash and the patched crash
#### Currently the script can receive 2 crashs, record each one's output, check difference and present it out by tkdiff.
### -test for various commands(as a test module) in crash utility, such as vtop/ptov/rd, etc.
#### Not yet, will be enriched later.
### -output the test results to a file in a specific format
#### Not yet, will be implemented later.
### -etc.(any comments?)