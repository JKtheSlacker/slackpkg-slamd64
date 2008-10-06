!/source\// && !/.asc/ {
       		sub(/\.tgz/,"")	
		INPUT=$NF
		fs=FS
		FS="/" ; OFS="/"
		$0=INPUT
		if ( $2 != "var" ) {
			DIR=$2
		} else {
			DIR="local"
		}
		FULLPACK=$NF
		NF=NF-1
		PATH=$0
		FS="-" ; OFS="-"
		$0=FULLPACK
		if ( NF > 3 ) {
			RELEASE=$NF
			ARCH=$(NF-1)
			VERSION=$(NF-2)
			NF=NF-3
			NAME=$0
		} else {
			RELEASE=none
			ARCH=none
			VERSION=none
			NAME=$0
		}
		FS=fs 
		print DIR" "NAME" "VERSION" "ARCH" "RELEASE" "NAME"-"VERSION"-"ARCH"-"RELEASE".tgz "PATH
}
