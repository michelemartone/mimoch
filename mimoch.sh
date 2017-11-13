#!/bin/bash
for p in  ${MODULEPATH//:/ } ; do
for m in `find $p -type f `; do
	bn=`basename $m`; test ${bn:0:1} = . && continue
	MN=`echo ${m} | sed 's/\s\s*/ /g' | rev | awk  -F / '{print $1"/"$2 }'| rev` 
	module avail ${MN} > /dev/null || { echo "internal error!"; exit 1; }
	#echo $m "->" $MN
	if test -f $m && grep -l '#%Module' >/dev/null $m  && MP=`module show $m | grep prepend-path.*MANPATH | sed 's/\s\s*/ /g'  | awk  -F ' ' '{print $3 }'` && test -n "$MP" ; then 
		for P in ${MP//:/ }; do
			test -d $P || echo "module $MN: \"$P\" is not a directory!" ; 
			#test -d $P && echo '[*]'" \"$P\" is ok" && ls $P ; 
		done; 
	fi  ; 
done    ;  
done #| grep is.not
