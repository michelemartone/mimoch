#!/bin/bash
# 
# Copyright 2018-2023 Michele MARTONE
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
test "`type -t module`" = function || { echo "no 'module' function in the current shell !"; exit -1; }
which grep >${DEV_NULL}|| exit -1
which date >${DEV_NULL}|| exit -1
which sed  >${DEV_NULL}|| exit -1
function my_which()
{
	which 2> ${DEV_NULL} || true
}
function module_avail()
{
	module avail ${1} 2>&1 | grep -v ^--- | sed 's/ *$//g; s/(default)//g' # trimming extra spaces and encompassing '(default)'
	true # rather than $? use test -n "`module_avail modulename`" here
}
DEF_DIRSTOCHECK='bdps' # see DIRSTOCHECK
function mk_hs() {
LMC_HELP=\
"MIMOCH
======
# MIchele's shell MOdulefiles CHecker

Usage alternatives:

${MD_BQ}
	$0 [options] <module-name> ...              # check specific modules (preferred style: uses existing MODULEPATH)
	$0 [options] <full-modulefile-pathname> ... # check specified modulefiles (fragile: assumes its dirname to be MODULEPATH)
	$0 [options] [[<modulefiles-dirpath>] <filter-find-pattern>] # search and check modulefiles
	Where [options] are:
	-a            # short for '-d ${DEF_DIRSTOCHECK} -H -M'
	-d SPECSTRING # check existence of specified directories. By default: ${DEF_DIRSTOCHECK}, where
	              # p: check .*PATH variables
	              # d: check .*DIR  variables
		      # s: check .*_SRC variables (if these start with http:// or https://, will be ignored)
	              # b: check .*BASE variables
	-h            # print help and exit (twice for Markdown markup)
	-t            # additional TAB-columnated and \"TAB:\"-prefixed output (easily grep'able, three columns). implies -M
	-q            # decrease verbosity
	-v            # increase verbosity (up to 4 times)
	-n            # exit with zero status (as long as no internal errors encountered)
	-i MAX        # will return non-zero status only if more than MAX mistakes found
	-m MAX        # will exit and return non-zero status immediately as soon MAX mistakes are reached
	-#            # tolerate a *.DIR or *.PATH variable value whose value begins with \"#\"
	-%            # tolerate a *.DIR or *.PATH variable value whose value contains \"%\" (if -% specified twice, truncate and only then check)
	-C            # check for presence of variables named _CC|_FC|_CXX (suffix)
	-E            # check and expand (via \'module avail\') list of specified modules
	-H            # check \`module help\` output
	-I            # in variables matching _INC check that each '-I/.* ' occurrence specifies an existing, space-free path
	-L            # check \`module load\` / \`module unload\`
	-M            # fetch contact list from a *_MAINTAINER_LIST variable; if specified twice (-MM), absence of such a variable will count as mistake.
	-P            # prereq / conflict module existence check
	-S            # in variables matching _SHLIB|_LIB|LDFLAGS|LIBS check that each '-L/.* ' occurrence specifies an existing, space-free path
	-T            # perform sanity test and exit (will use a temporary dir in ${DEV_SHM})
	-X            # if a *_USER_TEST or *_CMD_TEST variable is provided by a module, execute it in the shell using \`eval\` (implies module load/unload)
${MD_EQ}

Will look for common mistakes in shell modulefiles.
If any mistake if found, will exit with non-zero status.
It assumes output of \`module show\` to be sound in the current environment.
Note that mistakes might be detected twice.
False positives are also possible in certain cases.
Note that a badly written module can execute commands in your shell by sole load or show.
"
}
mk_hs
function on_help() { echo "${LMC_HELP}";exit; }
function result_msg() 
{
	echo -n "Checked ${1} modulefiles"
	if test -n "$TESTING" || [[ "$MISCTOCHECK" =~ X ]] ; then
		echo -n " (of which ${2} offered a test command)"
	fi
	if test -n "$TESTING" ; then
		echo -n ". Detected ${3} mistakes in ${4} modulefiles."
	else
		if test "${2}${3}" = 00 ; then
			echo -n ". No mistake detected."
		else
			echo -n ". Detected ${3} mistakes in ${4} modulefiles."
		fi
	fi
}
function sanitized_result_msg() 
{
	test `type -t result_msg` = function
	result_msg "$@" | sed 's/[^a-zA-Z0-9]/./g'
}
function do_test()
{
	echo " ===== Running self-tests ====="
	set -e
	export TESTING=1;
	#which $0 
	$0 -h > ${DEV_NULL} 
	test `$0 -h | wc -l` = 23 && echo " -h switch works"
	test -d ${DEV_SHM}
	test -w ${DEV_SHM}
	local TDIR=`mktemp -d ${DEV_SHM}/temporary-XXXX`
	test -d ${TDIR}
	trap "rm -fR ${TDIR}; echo ' ===== sanity test failed! ===== '" ERR
	trap "rm -fR ${TDIR}" EXIT
	local NON_EXISTING_DIR=/not-existent-dir
	local NON_EXISTING_FILE=gcc_
	local EXISTING_DIR=/bin
	test ! -f ${NON_EXISTING_FILE}
	test ! -d ${NON_EXISTING_DIR}
	test   -d ${EXISTING_DIR}
	test `type -t sanitized_result_msg` = function
	# MODULEPATH shall have no trailing slash; use e.g. ${MODULEPATH/%\//} 
	MODULEPATH=$TDIR $0       | grep `sanitized_result_msg 0 0 0 0`
	# shellcheck disable=SC1090
	( MODULEPATH=""  . $0;  ) | grep `sanitized_result_msg 0 0 0 0`;
	local MN=testmodule.tcl
	local MP=${TDIR}/${MN}
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
	cat > ${MP} << EOF
#%Module
# this module contains 0 mistakes
setenv MY_USER_MAINTAINER_LIST "many"
EOF
	{ MODULEPATH=$TDIR $0 -MM -v ${MN}       || true; } | grep `sanitized_result_msg 1 0 0 0`
	cat > ${MP} << EOF
#%Module
# this module contains 1 mistakes
setenv MY_USER_maintainer_list "many"
EOF
	{ MODULEPATH=$TDIR $0 -MM -v ${MN}       || true; } | grep `sanitized_result_msg 1 0 1 1`
	cat > ${MP} << EOF
#%Module
# this module contains 2 mistakes (we assume / exists)
setenv MY_PACKAGE_LIB "-L/path-to-non-existing-path -L/ -L/again-not-ok -L wrong-path -lwell-this-is-a-lib"
setenv MY_PACKAGE_INC "-I/path-to-non-existing-path -I/ -I/again-not-ok -I wrong-path -lwell-this-is-a-lib"
EOF
	{ MODULEPATH=$TDIR $0 -IS -v ${MN}       || true; } | grep `sanitized_result_msg 1 0 4 1`
	# shellcheck disable=SC2064
	cat > ${MP} << EOF
#%Module
# this module contains a mistake on _DIR (can't encode an URL)
setenv MY_USER_SRC  "http://url"
setenv MY_USER_DIR  "http://url"
EOF
	{ MODULEPATH=$TDIR $0 -vvv -d sd ${MN} ${MN} || true; } | grep `sanitized_result_msg 2 0 4 2`
	{ MODULEPATH=$TDIR $0 -vvv -d s  ${MN} ${MN} || true; } | grep `sanitized_result_msg 2 0 0 0`
	mkdir -p ${TDIR}/dir
	rm ${MP}
	local MP=${TDIR}/dir/${MN}
	cat > ${MP} << EOF
#%Module
prepend-path PATH ${NON_EXISTING_DIR}
EOF
	local MP=${TDIR}/dir/.version
	cat > ${MP} << EOF
#%Module
set ModulesVersion ${MN}
EOF
	{ MODULEPATH=$TDIR $0 -vvv -n -d p -L dir/${MN} || true; } | grep `sanitized_result_msg 1 0 1 1`
	echo " ===== Self-tests successful. ====="
	exit
}
OPTSTRING="ad:hi:m:nqtv#%CEHILMPSTX"
#CHECK_WHAT='';
VERBOSE=${VERBOSE:-0}
function echoX()
{
	if test ${VERBOSE} -ge ${1}; then
		shift;
		echo "$@"
	fi
}
function echo0() { echoX ${FUNCNAME: -1} "$@"; }
function echo1() { echoX ${FUNCNAME: -1} "$@"; }
function echo2() { echoX ${FUNCNAME: -1} "$@"; }
function echo3() { echoX ${FUNCNAME: -1} "$@"; }
function echo4() { echoX ${FUNCNAME: -1} "$@"; }
function contained_in()
{
	local EL="$1" LIST="$2"
	for LEL in $LIST; do
		if test "$EL" = "$LEL" ; then return ; fi
	done
	false
}
MISCTOCHECK=''
IGN_MISTAKES=0;
MAX_MISTAKES=0;
INTOPTS='';
DIRSTOCHECK=${DEF_DIRSTOCHECK}
while getopts $OPTSTRING NAME; do
	case $NAME in
		#a) CHECK_WHAT='a';;
		a) DIRSTOCHECK=${DEF_DIRSTOCHECK}; MISCTOCHECK='HM';;
		h) MISCTOCHECK+="h";;
		i) IGN_MISTAKES="$OPTARG"; [[ "$IGN_MISTAKES" =~ ^[0-9]+$ ]] || { echo "-$NAME switch needs a number! you gave ${IGN_MISTAKES}"; false; };;
		m) MAX_MISTAKES="$OPTARG"; [[ "$MAX_MISTAKES" =~ ^[0-9]+$ ]] || { echo "-$NAME switch needs a number! you gave ${MAX_MISTAKES}"; false; };;
		n) INTOPTS=n;;
		q) VERBOSE=$((VERBOSE-1));;
		t) MISCTOCHECK+="t";MISCTOCHECK+="M";; # TODO: missing test case
		v) VERBOSE=$((VERBOSE+1));;
		"#") MISCTOCHECK+="#";; # TODO: missing test case
		"%") MISCTOCHECK+="%";; # TODO: missing test case
		C) MISCTOCHECK+="C";;
		E) MISCTOCHECK+="E";;
		H) MISCTOCHECK+="H";;
		I) MISCTOCHECK+="I";;
		L) MISCTOCHECK+="L";;
		M) MISCTOCHECK+="M";;
		P) MISCTOCHECK+="P";;
		S) MISCTOCHECK+="S";;
		X) MISCTOCHECK+="X";;
		T) do_test;;
		d) DIRSTOCHECK="$OPTARG";;
		*) false
	esac
done
MD_BQ='';MD_EQ='';
# shellcheck disable=SC2016
[[ "$MISCTOCHECK" =~ h.*h ]] && { MD_BQ='```bash' MD_EQ='```' mk_hs;}
[[ "$MISCTOCHECK" =~ "h" ]] && { on_help; }
echo "# `date +%Y%m%d@%H:%M`: ${HOSTNAME}: $0 $*"
true
shift $((OPTIND-1))
test ${IGN_MISTAKES} -gt 0 && echo0 "# Will return non-zero status only if more than ${IGN_MISTAKES} mistakes found"
test ${MAX_MISTAKES} -gt 0 && echo0 "# Will tolerate up to ${MAX_MISTAKES} mistakes before returning non-zero status"
[[ "$MISCTOCHECK" =~ "#" ]] && { echo1 "# Directory variable value beginning with # will be ignored."; }
[[ "$MISCTOCHECK" =~ "%" ]] && { echo1 "# Directory variable value beginning with % will be ignored."; }
PERRS_CNT=0; # modulepath mistakes count
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
		if [[ "$MISCTOCHECK" =~ E ]] ; then
			echo0 "# Specified $ARG, expanding to modules: ${AM}"
		else
			#if test "${ARG}" != "${AM}" ; then
			if ! contained_in "${ARG}" "${AM}" ; then
				echo0 "# No module simply named ${ARG} (maybe try expansion with -E ?)."
				continue
			else
				AM="${ARG}"
				echo0 "# Specified modules ${ARG} (no expansion)."
			fi
		fi
		for MN in ${AM}; do
			MN=${MN/\(*/} # clean up of e.g. '(default)' suffix
			FN=$(module path ${MN});
			MD=${FN/%${MN}}; # cut postfix
			MN=${FN/#${MD}}; # cat prefix
			test "${FN}" = "${MD}${MN}"
			if test ! -d "${MD}" ; then echo4 "# skipping ${MD}: not a directory (you might have same-named modules in different dirs: fine)"; continue; fi; 
			MFA+=("${FN}");
			MNA+=("${MN}");
			MDA+=("${MD}");
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
			MFA+=("${FN}");
			MNA+=("${MN}");
			MDA+=("${MD}");
		done
	done
else
	USER_MP="$1"
	test -n "${USER_MP}" && echo1 "# User provided custom modules path: \"${USER_MP}\""
	MY_MODULEPATH=${1:-$MODULEPATH}
	test -f "${MY_MODULEPATH}" -a -n "${MY_MODULEPATH}" && MY_MODULEPATH=`dirname ${MY_MODULEPATH}`
	PATTERN=${2:-$PATTERN}
	echo "# Will scan for modulefiles through ${MY_MODULEPATH}"
	for MD in  ${MY_MODULEPATH//:/ } ; do # modulefiles directory
	echo1 "# Looking into directory ${MD} ${PATTERN:+ with pattern $PATTERN}"
	test -d ${MD} || { PERRS_CNT=$((PERRS_CNT+1)); echo0 "# Ignoring non-existing subpath ${MD} (counts as mistake)"; continue; }
	cd ${MD} && echo3 "# Stepped into directory ${MD}; will look for module files, with pattern \"${PATTERN}\"."
	# shellcheck disable=SC2044 # want loop, no read subshell
	for MF in `find . -type f ${PATTERN:+-iwholename \*$PATTERN\*}`; do # module file
		FN=${MD}/${MF}
		bn=`basename ${MF}`; test ${bn:0:1} = . && continue # no hidden files
		grep -l '#%Module' 2>&1 >${DEV_NULL} ${MF}  || continue # skip non-module files
		#MN=`echo ${MF} | sed 's/\s\s*/ /g' | rev | awk  -F / '{print $1"/"$2 }'| rev` # module name
		echo4 "# Found modulefile ${MF}"
		MN=${MF#./} # heading ./ might break `module av`
		MO="`MODULEPATH=${MD} module_avail ${MN}`"
		#test -z "${MO}" && { echo "internal error with module avail ${MN}: ${MF}!"; exit 1; } # we assert module to be valid
		if test ! -f "${USER_MP}" ; then test -z "${MO}" && { echo "skipping module avail ${MN}: ${MF}!"; continue; }; fi # e.g. tempdir/1.0~
		echo4 "# Modulefile is contained in the custom module path."
		MFA+=("${FN}");
		MNA+=("${MN}");
		MDA+=("${MD}");
		# echo "# Will check module ${MN}, modulefile ${FN}"
	done
	done
fi
TERRS_CNT=$((TERRS_CNT+PERRS_CNT));
#set -x
function abort_on_threshold()
{
	if test ${MAX_MISTAKES} != 0 -a $((TERRS_CNT+MERRS_CNT)) -gt ${MAX_MISTAKES}; then
		echo0 "# Encountered ${TERRS_CNT} mistakes (threshold was ${MAX_MISTAKES}): exiting now.";
		exit -1; 
	fi
}
function inc_err_cnt()
{
	MERRS_CNT=$((MERRS_CNT+1));
	echo3 "# this/total mistakes detected: $MERRS_CNT/$TERRS_CNT";
	abort_on_threshold
}
function mistake_csv()
{
	echo "TAB:	${1//	/}	${2//	/}	${3//	/}	${4//	/}	${5//	/}	${6//	/}"
}
function mlamu_test()
{
	test -n "$1"
	local CMD="( cd && module load ${MN} && eval ${1} && module unload ${MN}; )"
	test ${VERBOSE} -lt 4 && CMD+=" 2>&1 > ${DEV_NULL}"
	eval "${CMD}" || { 
		echo0 "module ${MN} [${FN}] ${MC} ${MI} \"$MI\"=\"${MV}\" test fails!${EI}" && inc_err_cnt;
		[[ "$MISCTOCHECK" =~ t ]] && mistake_csv "${MN}" "${FC}" "${MI}=${MV} test fails" "${MI}" "${MV}" "${EI}"
		true;
	 } 
}
function mhelp_test()
{
	test -n "$MN"
	local CMD="( MODULEPATH=${MD} module help ${MN}; )"
	test ${VERBOSE} -ge 4 && eval "${CMD}"
	local CMD="${CMD} 2>&1 | grep -q '^ERROR:'"
	if eval "${CMD}" ; then
		echo0 "module ${MN} [${FN}] help emits 'ERROR:'!${EI}" && inc_err_cnt;
		[[ "$MISCTOCHECK" =~ t ]] && mistake_csv "${MN}" "${FC}" "${FN} emits 'ERROR'!" "" "" "${EI}"
		true;
	fi
}
function check_flag_broken_ptns()
{
	test -n "$PF"
	test -n "$MN"
	test -n "$MPL"
	echo3 "Checking if $PF/ components of ${MA} are directories"
	local SHLRS="${MPL#$MA}"
	if [[   "${SHLRS}" =~ \  ]] ; then
		local TMV="$(echo "$SHLRS" | sed 's/^ *{//g;s/}.*//g')"
		echo3 "Considering: ${TMV}"
		for PD in $(echo "$TMV"  | sed 's/\('$PF'\/[^ ]*\)[ ]\+/\1\n/g' | grep '^'$PF'/' | sed 's/^'$PF'//g;s/ *$//g') ; do
			echo4 "Checking if the following $MI component a dir: $PD";
			test -d ${PD} || {
				echo0 "module ${MN} [${FN}] ${MC} ${MI} \"$MI\"=..\"${PD}\".. not a directory!${EI}" && inc_err_cnt;
				[[ "$MISCTOCHECK" =~ t ]] && mistake_csv "${MN}" "${FC}" "${MI}=${PD} not a directory" "${MI}" "${PD}" "${EI}"
				true;
			}
		done
	fi
}
function check_on_ptn()
{
	local CHK="$1"
	local PTN="$2"
	local PVID="$PTN"
	local MMPL=`echo "$MS" | grep "^${PVID} .*$"` || return 0;
	test -z "$MMPL" -a "$CHK" = REQ && { 
		echo3 "Missing of a *_${PTN} var!" 
		inc_err_cnt; 
		mistake_csv "${MN}" "${FC}" "Pattern ${PTN} is missing!" "" "" "${EI}";
		return 0; }; 
	test -n "${MMPL}" || return 0;
	while read MPL; do
	MC="`echo ${MPL} | awk  -F ' ' '{print $1 }'`" && \
	# path variable identifier expressions
	MI="`echo ${MPL} | awk  -F ' ' '{print $2 }'`" && \
	MV="`echo ${MPL} | awk  -F ' ' '{print $3 }'`" && \
	local MA=`echo "${MC} ${MI}" | grep "${PVID}" 2>&1 `      && \
	test -n "$MA" || return 0; # matching assignment
	echo2 "Checking if match on ${PVID}: match; \"${MA}\"";
	case $CHK in
		REQ)
			echo4 "module ${MN} sets  ${PTN}: good"
			return 0;
		;;
		DIR)
		[[ "${MI}" =~ ^.*_SRC$ && "${MV}" =~ ^https?:// ]] && { echo3 "# Directory variable value seems an URL: will be ignored (${MI}=${MV})." ; break; }
		local PD;
		for PD in ${MV//:/ }; do # path directory
			[[ "$MISCTOCHECK" =~ "#" ]] && test ${PD:0:1} = "#" && { echo3 "# Directory variable value begins with #: will be ignored (${MI}=${PD})." ; break; }
			[[ "$MISCTOCHECK" =~ "%" && "$PD" =~ "%" ]] && { 
				if [[ "$MISCTOCHECK" =~ "%%" ]] ; then
					PD=${PD%%%*}
					PD=${PD%/*}
					echo3 "# Directory variable ${MI} value contains %: truncated to ${PD}";
				else
					echo3 "# Directory variable value contains %: will be ignored (${MI}=${PD})." ; break;
				fi
			 }
			echo3 "Checking if $MI is a dir: $PD";
			test -d ${PD} || { 
				echo0 "module ${MN} [${FN}] ${MC} ${MI} \"$MI\"=\"${PD}\" not a directory!${EI}" && inc_err_cnt;
				[[ "$MISCTOCHECK" =~ t ]] && mistake_csv "${MN}" "${FC}" "${MI}=${PD} not a directory" "${MI}" "${PD}" "${EI}"
				true;
			 } 
		done; 
		;; 
		EXT)
			MV="`echo ${MPL} | cut -d \  -f 3- `" # this tolerates spaces
			if test "${VERBOSE}" -ge 3 ; then
				echo3 "Module $MN offers test commands variable $MI to be run; defined as: $MV"
			else
				echo2 "Module $MN offers test commands variable $MI - testing it."
			fi
			#echo CMD $CMD
			MEXET_CNT=$((MEXET_CNT+1));
			mlamu_test "\${$MI}"
		;; 
		CMP)
		true && { \
			echo3 "Checking if $MV in PATH"  
			if test -z "`my_which ${MV}`" ; then
				echo0 "module ${MN} [${FN}] ${MC} \"${MV}\" not in PATH!${EI}" && inc_err_cnt; 
				[[ "$MISCTOCHECK" =~ t ]] && mistake_csv "${MN}" "${FC}" "${MV} not in PATH!" "${MC}" "${MV}" "${EI}"
			fi; true
			}
		;; 
		MEL)
		true && { \
			test -z "`my_which ${MV}`" && \
				echo3 "Found MAINTAINER info: ${MV}" && \
				EI="[${MV//;/,}]" && FC="${MV%%;*}"
			true
			}
		;; 
		INC)
		true && { \
			# TODO: May consider further policy here. E.g.
			#  Shall one check this after prereq loading ?
			#  Shall one use specific compilers ?
			local PF=-I;
			check_flag_broken_ptns;
			if [[ ! "$MV" =~ ' ' ]] ; then
				true # we ignore this case
			fi
			}
		;; 
		SHL)
		true && { \
			# TODO: May consider further policy here. E.g.
			#  Shall one check this after prereq loading ?
			#  Shall one use specific compilers ?
			local PF=-L;
			check_flag_broken_ptns;
			if [[ ! "$MV" =~ ' ' ]] ; then
				true # we ignore this case
			fi
			}
		;;
		MEX)
		test "${MC}" == 'conflict' -o "${MC}" == 'prereq' && { \
			local RM;
			for RM in ${MI} ${MV}  ; do
				echo3 "Checking if a module: $RM"  
				if test -z "`module_avail ${RM} 2>&1`" ; then
					echo0 "module ${MN} [${FN}] ${MC} \"${RM}\" not an available module!${EI}" && inc_err_cnt; 
					[[ "$MISCTOCHECK" =~ t ]] && mistake_csv "${MN}" "${FC}" "${RM} not an available module!" "${MC}" "${RM}" "${EI}"
				fi
			done
			}
		;; 
		*) 
		echo1 "Internal error: internal command keyword not recognized!"
		false
	esac
	done < <( echo "$MMPL" ) # process substitution
}
[[ "$MISCTOCHECK" =~ t ]] && echo0 "# The following line is header of TAB-separated output you requested." \
			  && mistake_csv MODULE FIRSTCONTACT MISTAKE KEY VALUE CONTACTS
for MFI in `seq 0 $((${#MFA[@]}-1))`; do 
	FN="${MFA[$MFI]}" ;
	MN="${MNA[$MFI]}" ;
	MD="${MDA[$MFI]}" ;
	echo3 "# Will check module ${MN}, modulefile ${FN}, in dir ${MD}"
	cd ${MD}
	SRE='\(-path\|FILE\)' # in guessing email, avoid lines with this
	CI=`( grep @ ${MN} | grep -v -- "${SRE}" ) || true`
	ERE='[a-zA-Z.]\+@[a-zA-Z]\+.[a-zA-Z]\+'
	NRE='[^@]\+\s\+'
	# shellcheck disable=SC2001
	CL=`echo ${CI} | sed "s/\(${NRE}\)\\+\(${ERE}\)/\2 /g"`
	EI=''
	test -n "${CL}" && EI=" [${CL/% /}]" # extra contact info, from the comments (old way)
	echo1 "Checking ${FN}";
	# TODO: policy missing here. E.g.:
	#  To decide whether 'setenv .*_DOC\>' shall be dir or file.
	test "${VERBOSE}" -ge 4 && module show ${PWD}/${MN}
	MERRS_CNT=0; # module mistakes count
	MS=`module show ${PWD}/${MN} 2>&1 | sed 's/\s\s*/ /g' | grep -v '^\(--\|module-whatis\|  *\)'  `
	if [[ "$MISCTOCHECK" =~ M ]] ; then
		LPTN='setenv .*\(_MAINTAINER_LIST\)\>'
		check_on_ptn MEL "${LPTN}"
		if [[ "$MISCTOCHECK" =~ MM ]] ; then
			echo3 "Checking existence of ${LPTN}"
			check_on_ptn REQ "${LPTN}"
		fi
	fi
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
		check_on_ptn SHL 'setenv .*\(_SHLIB\|_LIB\|LDFLAGS\|LIBS\)\>'
	fi
	if [[ "$MISCTOCHECK" =~ X ]] ; then
		check_on_ptn EXT 'setenv .*\(_USER_TEST\|_CMD_TEST\)\>'
	fi
	if [[ "$MISCTOCHECK" =~ L ]] ; then
		echo3 "Checking load/unload ${FN}";
		mlamu_test true
	fi
	if [[ "$MISCTOCHECK" =~ H ]] ; then
		echo3 "Checking help ${FN}";
		mhelp_test
	fi
	test $MERRS_CNT = 0 || { TERRS_CNT=$((TERRS_CNT+MERRS_CNT)); FMA+=("${FN}"); if test -n "${CI}"; then MRA+=("${CL/% /} ${FN}"); else CL=''; fi; }
	echo1 "Checked ${FN}"
done    ; 
	result_msg ${#MFA[@]} ${MEXET_CNT} ${TERRS_CNT} ${#FMA[@]}
	echo " Took ${SECONDS}s".
if test ${TERRS_CNT} != 0; then
	CL="`for MR in "${MRA[@]}" ; do echo $MR; done | cut -d \  -f 1 | sort | uniq | tr "\n" ' ' `"
	#if test -n "${CL}" ; then echo "Modulefiles mention email addresses: ${CL}."; # gets confused by e,g, 'set maintainer "name surname <email>"'
	#for MR in "${MRA[@]}" ; do echo Contact: ${MR}; done
	if [[ "$INTOPTS" =~ n ]] || test ${TERRS_CNT} -le ${IGN_MISTAKES}; then exit 0; else exit -1; fi
else
	true;
fi
exit # success
