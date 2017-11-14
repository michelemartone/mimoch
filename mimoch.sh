#!/bin/bash
#module purge || exit
module unload lrz/$USER 
module load admin lrz/default 
MY_MODULEPATH=${1:-$MODULEPATH}
which grep || exit
which sed || exit
#MY_MODULEPATH='/lrz/sys/share/modules/extfiles'
for MD in  ${MY_MODULEPATH//:/ } ; do # modules directory
cd ${MD}
for MF in `find * -type f `; do # module file
	bn=`basename ${MF}`; test ${bn:0:1} = . && continue # no hidden files
	#MN=`echo ${MF} | sed 's/\s\s*/ /g' | rev | awk  -F / '{print $1"/"$2 }'| rev` # module name
	MN=${MF}
	MO="`module avail ${MN} 2>&1`"
	#test -z "${MO}" && { echo "internal error with module avail ${MN}: ${MF}!"; exit 1; } # we assert module to be valid
	test -z "${MO}" && { echo "skipping module avail ${MN}: ${MF}!"; continue; } # e.g. tempdir/1.0~
	for PVID in \
		'\(pre\|ap\)pend-path .*PATH\>' 'setenv .*DIR\>' 'setenv .*_SRC\>' 'setenv .*BASE\>' \
		'prereq .*' \
		; do # path variable identifier expressions
	#for PVID in '.p[p]end-path .*PATH\>' 'setenv .*DIR\>' 'setenv .*_SRC\>' 'setenv .*BASE\>'; do # path variable identifier expressions
	if test -f ${MF} && grep -l '#%Module' 2>&1 >/dev/null ${MF}  && \
		MPL="`module show ${MF} 2>&1 | sed 's/\s\s*/ /g' | grep "^${PVID} .*$" | grep -v '^\(--\|module-whatis\|  *\)'  `" && \
		MC="`echo ${MPL} | awk  -F ' ' '{print $1 }'`" && \
		MI="`echo ${MPL} | awk  -F ' ' '{print $2 }'`" && \
		MV="`echo ${MPL} | awk  -F ' ' '{print $3 }'`" && \
		MA=`echo "${MC} ${MI}" | grep "${PVID}" 2>&1 `      && \
		test -n "$MA" ; # matching assignment
		then
		test ${MC} == 'prereq' && { \
			for RM in ${MI} ${MV}  ; do
				test -z "`module avail ${RM} 2>&1`" && \
					echo "module ${MN} [${MF}] ${MC} \"${RM}\" not a module!" ; 
			done
			continue; }
		for PD in ${MV//:/ }; do # path directory
			test -d ${PD} || echo "module ${MN} [${MF}] ${MC} ${MI} \"${PD}\" not a directory!" ; 
		done; 
	fi  ; 
	done;
done    ; 
done	;
