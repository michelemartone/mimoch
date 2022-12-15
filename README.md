MIMOCH
======
# MIchele's shell MOdulefiles CHecker

Usage alternatives:

```bash
	./mimoch.sh [options] <module-name> ...              # check specific modules (preferred style: uses existing MODULEPATH)
	./mimoch.sh [options] <full-modulefile-pathname> ... # check specified modulefiles (fragile: assumes its dirname to be MODULEPATH)
	./mimoch.sh [options] [[<modulefiles-dirpath>] <filter-find-pattern>] # search and check modulefiles
	Where [options] are:
	-a            # short for '-d bdps -H -M'
	-d SPECSTRING # check existence of specified directories. By default: bdps, where
	              # p: check .*PATH variables
	              # d: check .*DIR  variables
	              # s: check .*_SRC variables
	              # b: check .*BASE variables
	-h            # print help and exit (twice for Markdown markup)
	-t            # additional TAB-columnated and "TAB:"-prefixed output (easily grep'able, three columns). implies -M
	-q            # decrease verbosity
	-v            # increase verbosity (up to 4 times)
	-n            # exit with zero status (as long as no internal errors encountered)
	-i MAX        # will return non-zero status only if more than MAX mistakes found
	-m MAX        # will exit and return non-zero status immediately as soon MAX mistakes are reached
	-#            # tolerate a *.DIR or *.PATH variable value whose value begins with "#"
	-%            # tolerate a *.DIR or *.PATH variable value whose value contains "%" (if -% specified twice, truncate and only then check)
	-C            # check for presence of variables named _CC|_FC|_CXX (suffix)
	-E            # check and expand (via \'module avail\') list of specified modules
	-H            # check `module help` output
	-I            # in variables matching _INC check that each '-I/.* ' occurrence specifies an existing, space-free path
	-L            # check `module load` / `module unload`
	-M            # fetch contact list from a *_MAINTAINER_LIST variable; if specified twice (-MM), absence of such a variable will count as mistake.
	-P            # prereq / conflict module existence check
	-S            # in variables matching _SHLIB|_LIB|LDFLAGS|LIBS check that each '-L/.* ' occurrence specifies an existing, space-free path
	-T            # perform sanity test and exit (will use a temporary dir in /dev/shm)
	-X            # if a *_USER_TEST or *_CMD_TEST variable is provided by a module, execute it in the shell using `eval` (implies module load/unload)
```

Will look for common mistakes in shell modulefiles.
If any mistake if found, will exit with non-zero status.
It assumes output of `module show` to be sound in the current environment.
Note that mistakes might be detected twice.
False positives are also possible in certain cases.
Note that a badly written module can execute commands in your shell by sole load or show.

