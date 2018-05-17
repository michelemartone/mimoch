#!/bin/bash
# 
# Copyright 2018 Michele MARTONE
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#  
#  
# Licensing: MIT (see e.g. https://opensource.org/licenses/MIT)
#  
#set -x
set -e
DEV_NULL=/dev/null
DEV_SHM=/dev/shm
test -w ${DEV_NULL}
test `type -t module` = function
which grep >${DEV_NULL}|| exit
which sed  >${DEV_NULL}|| exit
function my_which()
{
	which 2> ${DEV_NULL} || true
}
function module_avail()
{
	module avail ${1} 2>&1 | grep -v ^---
	true # rather than $? use test -n "`module_avail modulename`" here
}
DEF_DIRSTOCHECK='bdps' # see DIRSTOCHECK
LMC_HELP="Usage alternatives:

    $0 [options] <full-modulefile-pathname> ...                  # check specified modulefiles
    $0 [options] <module-name> ...                               # check specific modules (assumes a sane MODULEPATH)
    $0 [options] [[<modulefiles-dirpath>] <filter-find-pattern>] # search and check modulefiles
Where [options] are:
     -a            # short for '-d ${DEF_DIRSTOCHECK} -H'
     -d SPECSTRING # check existence of specified directories. By default: ${DEF_DIRSTOCHECK}, where
                   # p: check .*PATH variables
                   # d: check .*DIR  variables
                   # s: check .*_SRC variables
                   # b: check .*BASE variables
     -h            # print help and exit
     -q            # decrease verbosity
     -v            # increase verbosity (up to 4 times)
     -n            # exit with zero status (as long as no internal errors encountered)
     -C            # check for presence of eventually declared _CC|_FC|_CXX variables
     -H            # check \`module help\` output
     -I            # check include flags (still UNFINISHED)
     -L            # check \`module load\` / \`module unload\`
     -P            # prereq / conflict module existence check
     -S            # check link flags (still UNFINISHED)
     -T            # perform sanity test and exit (will use a temporary dir in ${DEV_SHM})
     -X            # if a *_USER_TEST variable is provided by a module, execute it in the shell using \`eval\` (implies module load/unload)

Will look for common mistakes in shell modulefiles.
If any mistake if found, will exit with non-zero status.
It assumes output of \`module show\` to be sound in the current environment.
Note that mistakes might be detected twice.
False positives are also possible in certain cases.
Note that a badly written module can execute commands in your shell by sole load or show.
"
function on_help() { echo "${LMC_HELP}";exit; }
function result_msg() 
{
	echo -n "Checked ${1} modulefiles (of which ${2} offered a test command). Detected ${3} mistakes in ${4} modulefiles."
}
function sanitized_result_msg() 
{
	test `type -t result_msg` = function
	result_msg $@ | sed 's/[^a-zA-Z0-9]/./g'
}
function do_test()
{
	echo " ===== Running self-tests ====="
	set -e
	#which $0 
	$0 -h > ${DEV_NULL} 
	test `$0 -h | wc -l` = 23 && echo " -h switch works"
	test -d ${DEV_SHM}
	test -w ${DEV_SHM}
	TDIR=`mktemp -d ${DEV_SHM}/temporary-XXXX`
	test -d ${TDIR}
	NON_EXISTING_DIR=/not-existent-dir
	NON_EXISTING_FILE=gcc_
	EXISTING_DIR=/bin
	test ! -f ${NON_EXISTING_FILE}
	test ! -d ${NON_EXISTING_DIR}
	test   -d ${EXISTING_DIR}
	test `type -t sanitized_result_msg` = function
	# MODULEPATH shall have no trailing slash; use e.g. ${MODULEPATH/%\//} 
	MODULEPATH=$TDIR $0       | grep `sanitized_result_msg 0 0 0 0`
	MODULEPATH=      $0       | grep `sanitized_result_msg 0 0 0 0`
	MN=testmodule.tcl
	MP=${TDIR}/${MN}
	cat > ${MP} << EOF
# this module is invalid: missing signature here
prepend-path PATH ${EXISTING_DIR}
EOF
	MODULEPATH=$TDIR $0       | grep `sanitized_result_msg 0 0 0 0`
	MODULEPATH=$TDIR $0 ${MP} | grep `sanitized_result_msg 0 0 0 0`
	cat > ${MP} << EOF
#%Module
# this module contains 0 mistakes
prepend-path PATH ${EXISTING_DIR}
setenv MY_USER_TEST true
setenv MY_CC ${NON_EXISTING_FILE}
EOF
	MODULEPATH=$TDIR $0       ${MP} | grep `sanitized_result_msg 1 0 0 0`
	{ MODULEPATH=$TDIR $0 -C    ${MP} || true;} | grep `sanitized_result_msg 1 0 1 1`
	MODULEPATH=$TDIR $0 -vvvv ${MP} | grep `sanitized_result_msg 1 0 0 0`
	MODULEPATH=$TDIR $0 -vvvv ${MN} | grep `sanitized_result_msg 1 0 0 0`
	MODULEPATH=$TDIR $0 -L -X ${MN} | grep `sanitized_result_msg 1 1 0 0`
	cat > ${MP} << EOF
#%Module
# this module contains 5 mistakes
prepend-path PATH ${NON_EXISTING_DIR}
prereq non-existent-module
setenv MY_USER_TEST false
setenv MY_USER_DIR  ${NON_EXISTING_DIR}
setenv MY_USER_SRC  ${NON_EXISTING_DIR}
setenv MY_USER_BASE ${NON_EXISTING_DIR}
EOF
	{ MODULEPATH=$TDIR $0 -X    ${MN}       || true; } | grep `sanitized_result_msg 1 1 5 1`
	{ MODULEPATH=$TDIR $0 -d p  ${MN}       || true; } | grep `sanitized_result_msg 1 0 1 1`
	{ MODULEPATH=$TDIR $0 -d '' ${MN}       || true; } | grep `sanitized_result_msg 1 0 0 0`
	{ MODULEPATH=$TDIR $0 -d '' ${MN} ${MN} || true; } | grep `sanitized_result_msg 2 0 0 0`
	{ MODULEPATH=$TDIR $0    -v ${MN}       || true; } | grep `sanitized_result_msg 1 0 4 1`
	{ MODULEPATH=$TDIR $0    -v ${MN} ${MN} || true; } | grep `sanitized_result_msg 2 0 8 2`
	{ MODULEPATH=$TDIR $0 -P -v ${MN}       || true; } | grep `sanitized_result_msg 1 0 4 1`
	trap "rm -fR ${TDIR}" EXIT
	echo " ===== Self-tests successful. ====="
	exit
}
echo "# ${HOSTNAME}: $0 $@"
OPTSTRING="ad:hnqvCHILPSTX"
#OPTSTRING="ah"
#CHECK_WHAT='';
VERBOSE=${VERBOSE:-0}
function echoX()
{
	if test ${VERBOSE} -ge ${1}; then
		shift;
		echo $@
	fi
}
function echo0() { echoX ${FUNCNAME: -1} $@; }
function echo3() { echoX ${FUNCNAME: -1} $@; }
MISCTOCHECK=''
INTOPTS='';
DIRSTOCHECK=${DEF_DIRSTOCHECK}
while getopts $OPTSTRING NAME; do
	case $NAME in
		#a) CHECK_WHAT='a';;
		a) DIRSTOCHECK=${DEF_DIRSTOCHECK}; MISCTOCHECK='H';;
		h) on_help;;
		n) INTOPTS=n;;
		q) VERBOSE=$((VERBOSE-1));;
		v) VERBOSE=$((VERBOSE+1));;
		C) MISCTOCHECK+="C";;
		H) MISCTOCHECK+="H";;
		I) MISCTOCHECK+="I";;
		L) MISCTOCHECK+="L";;
		P) MISCTOCHECK+="P";;
		S) MISCTOCHECK+="S";;
		X) MISCTOCHECK+="X";;
		T) do_test;;
		d) DIRSTOCHECK="$OPTARG";;
		*) false
	esac
done
shift $((OPTIND-1))
TERRS_CNT=0; # total module mistakes count
MEXET_CNT=0; # module execution tests count
declare -a VIDP
if [[ "$DIRSTOCHECK" =~ p ]]; then VIDP+=('\(pre\|ap\)pend-path .*PATH\>'); fi;
if [[ "$DIRSTOCHECK" =~ d ]]; then VIDP+=('setenv .*DIR\>'); fi;
if [[ "$DIRSTOCHECK" =~ s ]]; then VIDP+=('setenv .*_SRC\>'); fi;
if [[ "$DIRSTOCHECK" =~ b ]]; then VIDP+=('setenv .*BASE\>'); fi;
test -z "$MISCTOCHECK$DIRSTOCHECK" && { echo "# No test specified. Are you sure this is what you intended ?"; }
declare -a MRA # modulefiles responsabilities array
declare -a MFA # modulefiles array
declare -a MDA # modulefiles dir array
declare -a MNA # modulefiles names array (indices as in MFA)
declare -a FMA # faulty modulefiles array
test -z "${MODULEPATH}" && { echo "# Your MODULEPATH variable is empty. Expect trouble!"; }
if test -n "${1}" -a -n "${MODULEPATH}" && test -n "`module_avail ${1}`" ; then
	for ARG ; do
		AM=`module_avail ${ARG}`
		echo "# Specified $ARG, addressing modules: $AM"
		for MN in ${AM}; do
			MN=${MN/\(*/} # clean up of e.g. '(default)' suffix
			FN=$(module path ${MN});
			MD=${FN/%${MN}};
			MFA+=(${FN});
			MNA+=(${MN});
			MDA+=(${MD});
		done
	done
elif test -f "${1}" -a ! -d "${1}" ; then
	for ARG ; do
		grep -l '#%Module' 2>&1 >${DEV_NULL} ${ARG}  || continue # skip non-module files
		echo "# Specified module $ARG"
		for MN in `basename ${ARG}`; do
			MN=${MN/\(*/} # clean up of e.g. '(default)' suffix
			FN=${ARG}
			MD=${FN/%${MN}};
			MFA+=(${FN});
			MNA+=(${MN});
			MDA+=(${MD});
		done
	done
else
	USER_MP="$1"
	MY_MODULEPATH=${1:-$MODULEPATH}
	test -f "${MY_MODULEPATH}" -a -n "${MY_MODULEPATH}" && MY_MODULEPATH=`dirname ${MY_MODULEPATH}`
	PATTERN=${2:-$PATTERN}
	echo "# Will check through modules around ${MY_MODULEPATH}"
	for MD in  ${MY_MODULEPATH//:/ } ; do # modules directory
	test ${VERBOSE} -ge 1 && echo "# Looking into ${MD} ${PATTERN:+ with pattern $PATTERN}"
	cd ${MD}
	for MF in `find -type f ${PATTERN:+-iwholename \*$PATTERN\*}`; do # module file
		FN=${MD}/${MF}
		bn=`basename ${MF}`; test ${bn:0:1} = . && continue # no hidden files
		grep -l '#%Module' 2>&1 >${DEV_NULL} ${MF}  || continue # skip non-module files
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
	MERRS_CNT=$((MERRS_CNT+1));
	echo3 "# this/total mistakes detected: $MERRS_CNT/$TERRS_CNT";
}
function mlamu_test()
{
		test -n "$1"
		CMD="( cd && module load ${MN} && eval ${1} && module unload ${MN}; )"
		eval "${CMD}" || { echo "module ${MN} [${FN}] ${MC} ${MI} \"$MI\"=\"${MV}\" test fails!${EI}" && inc_err_cnt; } 
}
function mhelp_test()
{
		test -n "$MN"
		CMD="( module help ${MN}; )"
		test ${VERBOSE} -ge 4 && eval "${CMD}"
		CMD="${CMD} 2>&1 | grep -q '^ERROR:'"
		if eval "${CMD}" ; then
			echo "module ${MN} [${FN}] help emits 'ERROR:'!${EI}" && inc_err_cnt;
		fi
}
function check_on_ptn()
{
	CHK="$1"
	PTN="$2"
	PVID="$PTN"
	MMPL=`echo "$MS" | grep "^${PVID} .*$"` && \
		test -n "${MMPL}" || return 0;
	while read MPL; do
	MC="`echo ${MPL} | awk  -F ' ' '{print $1 }'`" && \
	# path variable identifier expressions
	MI="`echo ${MPL} | awk  -F ' ' '{print $2 }'`" && \
	MV="`echo ${MPL} | awk  -F ' ' '{print $3 }'`" && \
	MA=`echo "${MC} ${MI}" | grep "${PVID}" 2>&1 `      && \
	test -n "$MA" || return 0; # matching assignment
	test "${VERBOSE}" -ge 2 && echo "Checking if match on ${PVID}: match; \"${MA}\""  
	case $CHK in
		DIR)
		for PD in ${MV//:/ }; do # path directory
			echo3 "Checking if $MI is a dir: $PD";
			test -d ${PD} || { echo0 "module ${MN} [${FN}] ${MC} ${MI} \"$MI\"=\"${PD}\" not a directory!${EI}" && inc_err_cnt; } 
		done; 
		;; 
		EXT)
			MV="`echo ${MPL} | cut -d \  -f 3- `" # this tolerates spaces
			echo3 "Module $MN offers test commands variable $MI, defined as $MV"
			#echo CMD $CMD
			MEXET_CNT=$((MEXET_CNT+1));
			mlamu_test "\${$MI}"
		;; 
		CMP)
		true && { \
			echo3 "Checking if $MV in PATH"  
			test -z "`my_which ${MV}`" && \
				echo0 "module ${MN} [${FN}] ${MC} \"${MV}\" not in PATH!${EI}" && inc_err_cnt; 
			true
			}
		;; 
		INC)
		true && { \
			echo3 "NEED CHECK if $MV is OK"  
			# TODO: write me
			true
			}
		;; 
		SHL)
		true && { \
			echo3 "NEED CHECK if $MV is OK"  
			# TODO: write me
			true
			}
		;; 
		MEX)
		test "${MC}" == 'conflict' -o "${MC}" == 'prereq' && { \
			for RM in ${MI} ${MV}  ; do
				echo3 "Checking if a module: $RM"  
				test -z "`module_avail ${RM} 2>&1`" && \
					echo0 "module ${MN} [${FN}] ${MC} \"${RM}\" not an available module!${EI}" && inc_err_cnt; 
			done
			}
		;; 
		*) false
	esac
	done < <( echo "$MMPL" ) # process substitution
}
for MFI in `seq 0 $((${#MFA[@]}-1))`; do 
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
	MERRS_CNT=0; # module mistakes count
	MS=`module show ${PWD}/${MN} 2>&1 | sed 's/\s\s*/ /g' | grep -v '^\(--\|module-whatis\|  *\)'  `
	for PVID in "${VIDP[@]}" ;
		do
		check_on_ptn DIR "$PVID"; continue
	done;
	if [[ "$MISCTOCHECK" =~ P ]] ; then
		check_on_ptn MEX '\(prereq\|conflict\) .*'
	fi
	if [[ "$MISCTOCHECK" =~ C ]] ; then
		check_on_ptn CMP 'setenv .*\(_CC\|_FC\|_CXX\)'
	fi
	if [[ "$MISCTOCHECK" =~ I ]] ; then
		check_on_ptn INC 'setenv .*\(_INC\)\>'
	fi
	if [[ "$MISCTOCHECK" =~ S ]] ; then
		check_on_ptn SHL 'setenv .*\(_SHLIB\|_LIB\)\>'
	fi
	if [[ "$MISCTOCHECK" =~ X ]] ; then
		check_on_ptn EXT 'setenv .*_USER_TEST\>'
	fi
	if [[ "$MISCTOCHECK" =~ L ]] ; then
		echo3 "Checking load/unload ${FN}";
		mlamu_test true
	fi
	if [[ "$MISCTOCHECK" =~ H ]] ; then
		echo3 "Checking help ${FN}";
		mhelp_test
	fi
	test $MERRS_CNT = 0 || { TERRS_CNT=$((TERRS_CNT+MERRS_CNT)); FMA+=(${FN}); if test -n "${CI}"; then MRA+=("${CL/% /} ${FN}"); else CL=''; fi; }
	test ${VERBOSE} -ge 1 && echo "Checked ${FN}"
done    ; 
	result_msg ${#MFA[@]} ${MEXET_CNT} ${TERRS_CNT} ${#FMA[@]}
	echo " Took ${SECONDS}s".
if test ${TERRS_CNT} != 0; then
	CL="`for MR in "${MRA[@]}" ; do echo $MR; done | cut -d \  -f 1 | sort | uniq | tr "\n" ' ' `"
	if test -n "${CL}" ; then echo "Modules mention email addresses: ${CL}."; fi
	#for MR in "${MRA[@]}" ; do echo Contact: ${MR}; done
	if [[ "$INTOPTS" =~ n ]]; then exit 0; else exit -1; fi
else
	true;
fi
exit # success
