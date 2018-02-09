#!/bin/bash
#Modules checking script -- for internal use -- please do not distribute.
#Author: Michele Martone
#module purge || exit
#set -x
#set -e
module unload lrz/$USER 
module load admin lrz/default 
USER_MP="$1"
MY_MODULEPATH=${1:-$MODULEPATH}
test -f ${MY_MODULEPATH} && MY_MODULEPATH=`dirname ${MY_MODULEPATH}`
PATTERN=${2:-$PATTERN}
${VERBOSE:=0}
which grep || exit
which sed || exit
ERRORS=0
#MY_MODULEPATH='/lrz/sys/share/modules/extfiles'
for MD in  ${MY_MODULEPATH//:/ } ; do # modules directory
test ${VERBOSE} == 1 && echo looking into ${MD} ${PATTERN:+ with pattern $PATTERN}
cd ${MD}
for MF in `find -type f ${PATTERN:+-iwholename \*$PATTERN\*}`; do # module file
	FN=${MD}/${MF}
	bn=`basename ${MF}`; test ${bn:0:1} = . && continue # no hidden files
	grep -l '#%Module' 2>&1 >/dev/null ${MF}  || continue # skip non-module files
	#MN=`echo ${MF} | sed 's/\s\s*/ /g' | rev | awk  -F / '{print $1"/"$2 }'| rev` # module name
	MN=${MF}
	MO="`module avail ${MN} 2>&1`"
	#test -z "${MO}" && { echo "internal error with module avail ${MN}: ${MF}!"; exit 1; } # we assert module to be valid
	if test ! -f "${USER_MP}" ; then test -z "${MO}" && { echo "skipping module avail ${MN}: ${MF}!"; continue; }; fi # e.g. tempdir/1.0~
	CI=`grep @ ${MF}` 
	ERE='[a-zA-Z.]\+@lrz.de'
	NRE='[^@]\+\s\+'
	CL=`echo ${CI} | sed "s/\(${NRE}\)\\+\(${ERE}\)/\2 /g"`
	EI=''
	test -n "${CL}" && EI=" [${CL/% /}]" # extra info
	test ${VERBOSE} == 1 && echo "Checking ${FN}"
	for PVID in \
		'\(pre\|ap\)pend-path .*PATH\>' 'setenv .*DIR\>' 'setenv .*_SRC\>' 'setenv .*BASE\>' \
		'prereq .*' \
		; do # path variable identifier expressions
		#for PVID in '.p[p]end-path .*PATH\>' 'setenv .*DIR\>' 'setenv .*_SRC\>' 'setenv .*BASE\>'; do # path variable identifier expressions
		MPL="`module show ${PWD}/${MF} 2>&1 | sed 's/\s\s*/ /g' | grep "^${PVID} .*$" | grep -v '^\(--\|module-whatis\|  *\)'  `" && \
		test -n "${MPL}" && \
		MC="`echo ${MPL} | awk  -F ' ' '{print $1 }'`" && \
		MI="`echo ${MPL} | awk  -F ' ' '{print $2 }'`" && \
		MV="`echo ${MPL} | awk  -F ' ' '{print $3 }'`" && \
		MA=`echo "${MC} ${MI}" | grep "${PVID}" 2>&1 `      && \
		test -n "$MA" || continue # matching assignment
		test "${VERBOSE}" -ge 2 && echo "Checking if match on ${PVID}: match; ${MA}"  
		#echo $MD/${MF}
		test "${MC}" == 'prereq' && { \
			for RM in ${MI} ${MV}  ; do
				test -z "`module avail ${RM} 2>&1`" && \
					echo "module ${MN} [${FN}] ${MC} \"${RM}\" not a module!${EI}"; 
			done
			continue; }
		for PD in ${MV//:/ }; do # path directory
			test -d ${PD} || { echo "module ${MN} [${FN}] ${MC} ${MI} \"${PD}\" not a directory!${EI}" && ERRORS=$((ERRORS+1)); } 
		done; 
	done;
done    ; 
done	;
if test ${ERRORS} != 0; then
	echo "Found ${ERRORS} errors".
	exit -1 # failure
fi
exit # success
