#!/bin/bash
module purge
MY_MODULEPATH=${1:-$MODULEPATH}
#MY_MODULEPATH='/lrz/sys/share/modules/extfiles'
for PD in  ${MY_MODULEPATH//:/ } ; do
for MF in `find ${PD} -type f `; do
	bn=`basename ${MF}`; test ${bn:0:1} = . && continue
	MN=`echo ${MF} | sed 's/\s\s*/ /g' | rev | awk  -F / '{print $1"/"$2 }'| rev` 
	module avail ${MN} > /dev/null || { echo "internal error!"; exit 1; }
	for PVID in 'prepend-path .*PATH\>' 'setenv .*DIR\>' 'setenv .*_SRC\>'; do
	if test -f ${MF} && grep -l '#%Module' >/dev/null ${MF}  && \
		#MPL="`module show $MF | sed 's/\s\s*/ /g' | grep -v '^\(--\|module-whatis\|  *\)' | grep '^[\s]\+' `" && \
		MPL="`module show ${MF} | sed 's/\s\s*/ /g' | grep "^${PVID} .*$"  `" && \
		MC="`echo ${MPL} | awk  -F ' ' '{print $1 }'`" && \
		MI="`echo ${MPL} | awk  -F ' ' '{print $2 }'`" && \
		MV="`echo ${MPL} | awk  -F ' ' '{print $3 }'`"  && \
		MA=`echo "${MC} ${MI}" | grep "${PVID}" ` && \
		test -n "$MA" ; 
		then
		for P in ${MV//:/ }; do
			test -d ${P} || echo "module ${MN} [${MF}] : ${MI}=\"$P\" not a directory!" ; 
		done; 
	fi  ; 
	done;
done    ;  
done #| grep is.not
