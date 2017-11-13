#!/bin/bash
module purge
MY_MODULEPATH=${1:-$MODULEPATH}
#MY_MODULEPATH='/lrz/sys/share/modules/extfiles'
for MD in  ${MY_MODULEPATH//:/ } ; do # modules directory
for MF in `find ${MD} -type f `; do # module file
	bn=`basename ${MF}`; test ${bn:0:1} = . && continue # no hidden files
	MN=`echo ${MF} | sed 's/\s\s*/ /g' | rev | awk  -F / '{print $1"/"$2 }'| rev` # module name
	module avail ${MN} > /dev/null || { echo "internal error!"; exit 1; } # we assert module to be valid
	for PVID in 'prepend-path .*PATH\>' 'setenv .*DIR\>' 'setenv .*_SRC\>' 'setenv .*BASE\>'; do # path variable identifier expressions
	if test -f ${MF} && grep -l '#%Module' >/dev/null ${MF}  && \
		MPL="`module show ${MF} | sed 's/\s\s*/ /g' | grep "^${PVID} .*$" | grep -v '^\(--\|module-whatis\|  *\)'  `" && \
		MC="`echo ${MPL} | awk  -F ' ' '{print $1 }'`" && \
		MI="`echo ${MPL} | awk  -F ' ' '{print $2 }'`" && \
		MV="`echo ${MPL} | awk  -F ' ' '{print $3 }'`" && \
		MA=`echo "${MC} ${MI}" | grep "${PVID}" `      && \
		test -n "$MA" ; # matching assignment
		then
		for PD in ${MV//:/ }; do # path directory
			test -d ${PD} || echo "module ${MN} [${MF}] : ${MI}=\"$PD\" not a directory!" ; 
		done; 
	fi  ; 
	done;
done    ; 
done	;
