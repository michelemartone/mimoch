#!/bin/bash
#A modulefiles checking script -- INCOMPLETE, FOR PERSONAL USE -- please do not distribute.
#Author: Michele Martone
#set -x
set -e
which grep >/dev/null|| exit
which sed  >/dev/null|| exit
function module_avail()
{
	module avail ${1} 2>&1 | grep -v ^---
	true # rather than $? use test -n "`module_avail modulename`" here
}
DEF_DIRSTOCHECK='bdps'
#DEF_DIRSTOCHECK='bdpPs'
LMC_HELP="Usage:

    $0 [options] <full-modulefile-pathname>                  # check specified modulefile
    $0 [options] <module-name>                               # check modulefiles for specific module
    $0 [options] <modulefiles-dirpath> <filter-find-pattern> # search and check modulefiles
    Where [options] are:
     -d SPECSTRING # check existence of specified directories. By default: ${DEF_DIRSTOCHECK}, where
                   # p: check .*PATH variables
                   # d: check .*DIR  variables
                   # s: check .*_SRC variables
                   # b: check .*BASE variables
     -h            # print help and exit
     -v            # verbose (specify up to 4 times to increase verbosity)
     -X            # if a *_USER_TEST variable is provided by a module, evaluate it (will load/unload the module)
     -L            # load / unload test

Will look for common mistakes in modulefiles.
It assumes output of \`module show\` to be sound in the current environment.
Note that mistakes might be detected twice.
False positives are also possible in certain cases.
"
function on_help() { echo "${LMC_HELP}";exit; }
OPTSTRING="d:hvLX"
#OPTSTRING="ah"
#CHECK_WHAT='';
VERBOSE=${VERBOSE:-0}
MISCTOCHECK=''
DIRSTOCHECK=${DEF_DIRSTOCHECK}
while getopts $OPTSTRING NAME; do
	case $NAME in
		#a) CHECK_WHAT='a';;
		h) on_help;;
		v) VERBOSE=$((VERBOSE+1));;
		X) MISCTOCHECK+="X";;
		L) MISCTOCHECK+="L";;
		d) DIRSTOCHECK="$OPTARG";;
		*) false
	esac
done
shift $((OPTIND-1))
ERRORS=0
declare -a VIDP
#if [[ "$DIRSTOCHECK" =~ P ]]; then VIDP+=('prereq .*'); fi;
if [[ "$DIRSTOCHECK" =~ p ]]; then VIDP+=('\(pre\|ap\)pend-path .*PATH\>'); fi;
if [[ "$DIRSTOCHECK" =~ d ]]; then VIDP+=('setenv .*DIR\>'); fi;
if [[ "$DIRSTOCHECK" =~ s ]]; then VIDP+=('setenv .*_SRC\>'); fi;
if [[ "$DIRSTOCHECK" =~ b ]]; then VIDP+=('setenv .*BASE\>'); fi;
declare -a MRA # modulefiles responsabilities array
declare -a MFA # modulefiles array
declare -a MDA # modulefiles dir array
declare -a MNA # modulefiles names array (indices as in MFA)
declare -a FMA # faulty modulefiles array
if test -n "$1" && test -n "${AM:=`module_avail $1`}" ; then
	test $# = 1 || on_help
	echo "# Specified $1, addressing modules: $AM "
	for MN in $AM; do
		MN=${MN/\(*/} # clean up of e.g. '(default)' suffix
		FN=$(module path ${MN});
		MD=${FN/%${MN}};
		MFA+=(${FN});
		MNA+=(${MN});
		MDA+=(${MD});
	done
else
	USER_MP="$1"
	MY_MODULEPATH=${1:-$MODULEPATH}
	test -f ${MY_MODULEPATH} && MY_MODULEPATH=`dirname ${MY_MODULEPATH}`
	PATTERN=${2:-$PATTERN}
	echo "# Will check through modules around ${MY_MODULEPATH}"
	for MD in  ${MY_MODULEPATH//:/ } ; do # modules directory
	test ${VERBOSE} -ge 1 && echo Looking into ${MD} ${PATTERN:+ with pattern $PATTERN}
	cd ${MD}
	for MF in `find -type f ${PATTERN:+-iwholename \*$PATTERN\*}`; do # module file
		FN=${MD}/${MF}
		bn=`basename ${MF}`; test ${bn:0:1} = . && continue # no hidden files
		grep -l '#%Module' 2>&1 >/dev/null ${MF}  || continue # skip non-module files
		#MN=`echo ${MF} | sed 's/\s\s*/ /g' | rev | awk  -F / '{print $1"/"$2 }'| rev` # module name
		MN=${MF}
		MO="`module_avail ${MN}`"
		#test -z "${MO}" && { echo "internal error with module avail ${MN}: ${MF}!"; exit 1; } # we assert module to be valid
		if test ! -f "${USER_MP}" ; then test -z "${MO}" && { echo "skipping module avail ${MN}: ${MF}!"; continue; }; fi # e.g. tempdir/1.0~
		MFA+=(${FN});
		MNA+=(${MN});
		MDA+=(${MD});
		# echo "# Will check module ${MN}, modulefile ${FN}"
	done
	done
fi
#set -x
function inc_err_cnt()
{
	MERRORS=$((MERRORS+1));
}
function mlamu_test()
{
		test -n "$1"
		CMD="( cd && module load ${MN} && eval ${1} && module unload ${MN}; )"
		eval "${CMD}" || { echo "module ${MN} [${FN}] ${MC} ${MI} \"$MI\"=\"${MV}\" test fails!${EI}" && inc_err_cnt; } 
}
function check_on_ptn()
{
	CHK="$1"
	PTN="$2"
	PVID="$PTN"
	MPL=`echo "$MS" | grep "^${PVID} .*$"` && \
	test -n "${MPL}" && \
	MC="`echo ${MPL} | awk  -F ' ' '{print $1 }'`" && \
	# path variable identifier expressions
	MI="`echo ${MPL} | awk  -F ' ' '{print $2 }'`" && \
	MV="`echo ${MPL} | awk  -F ' ' '{print $3 }'`" && \
	MA=`echo "${MC} ${MI}" | grep "${PVID}" 2>&1 `      && \
	test -n "$MA" || continue # matching assignment
	test "${VERBOSE}" -ge 2 && echo "Checking if match on ${PVID}: match; \"${MA}\""  
	case $CHK in
		DIR)
		for PD in ${MV//:/ }; do # path directory
			test "${VERBOSE}" -ge 3 && echo "Checking if $MI is a dir: $PD"  
			test -d ${PD} || { echo "module ${MN} [${FN}] ${MC} ${MI} \"$MI\"=\"${PD}\" not a directory!${EI}" && inc_err_cnt; } 
		done; 
		;; 
		EXT)
			MV="`echo ${MPL} | cut -d \  -f 3- `" # this tolerates spaces
			test "${VERBOSE}" -ge 3 && \
				echo "Module $MN offers test commands variable $MI, defined as $MV"
			#echo CMD $CMD
			mlamu_test "\${$MI}"
		;; 
		MEX)
		test "${MC}" == 'conflict' -o "${MC}" == 'prereq' && { \
			for RM in ${MI} ${MV}  ; do
				test "${VERBOSE}" -ge 3 && echo "Checking if a module: $RM"  
				test -z "`module_avail ${RM} 2>&1`" && \
					echo "module ${MN} [${FN}] ${MC} \"${RM}\" not a module!${EI}" && inc_err_cnt; 
			done
			}
		;; 
		*) false
	esac
}
for MFI in `seq 1 $((${#MFA[@]}-1))`; do 
	FN="${MFA[$MFI]}" ;
	MN="${MNA[$MFI]}" ;
	MD="${MDA[$MFI]}" ;
	# echo "# Will check module ${MN}, modulefile ${FN}"
	cd ${MD}
	CI=`grep @ ${MN} || true` 
	ERE='[a-zA-Z.]\+@[a-zA-Z]\+.[a-zA-Z]\+'
	NRE='[^@]\+\s\+'
	CL=`echo ${CI} | sed "s/\(${NRE}\)\\+\(${ERE}\)/\2 /g"`
	EI=''
	test -n "${CL}" && EI=" [${CL/% /}]" # extra contact info
	test ${VERBOSE} -ge 1 && echo "Checking ${FN}"
	# TODO: need to decide whether 'setenv .*_DOC\>' shall be dir or file.
	test "${VERBOSE}" -ge 4 && module show ${PWD}/${MN}
	MERRORS=0;
	MS=`module show ${PWD}/${MN} 2>&1 | sed 's/\s\s*/ /g' | grep -v '^\(--\|module-whatis\|  *\)'  `
	for PVID in "${VIDP[@]}" ;
		do
		check_on_ptn DIR "$PVID"; continue
		check_on_ptn MEX "$PVID"; continue
	done;
	if [[ "$MISCTOCHECK" =~ X ]] ; then
		check_on_ptn EXT 'setenv .*_USER_TEST\>'
	fi
	if [[ "$MISCTOCHECK" =~ L ]] ; then
		test ${VERBOSE} -ge 3 && echo "Checking load/unload ${FN}"
		mlamu_test true
	fi
	test $MERRORS = 0 || { ERRORS=$((ERRORS+MERRORS)); FMA+=(${FN}); if test -n "${CI}"; then MRA+=("${CL/% /} ${FN}"); else CL=''; fi; }
	test ${VERBOSE} -ge 1 && echo "Checked ${FN}"
done    ; 
if test ${ERRORS} != 0; then
	echo "Checked ${#MFA[@]} modulefiles. Detected ${ERRORS} errors in ${#FMA[@]} modulefiles. Took ${SECONDS}s".
	CL="`for MR in "${MRA[@]}" ; do echo $MR; done | cut -d \  -f 1 | sort | uniq | tr "\n" ' ' `"
	if test -n "${CL}" ; then echo "Modules mention email addresses: ${CL}."; fi
	#for MR in "${MRA[@]}" ; do echo Contact: ${MR}; done
	exit -1 # failure
fi
exit # success
