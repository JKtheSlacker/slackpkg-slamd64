/^(a|ap|d|e|f|k|kde|kdei|l|n|t|tcl|x|xap|y)\/([a-zA-Z0-9_\+]+)-.*:.* ([Ad]dded|[Ss]plit|[Rr]enamed|[Mm]oved|[Nn]ame [Cc]hange|NAME CHANGE).*/ {
	INPUT=$1
	fs=FS
	FS="/" ; OFS="/"
	$0=INPUT
	FULLPACK=$NF
	FS="-" ; OFS="-"
	$0=FULLPACK
	NF=NF-3
	FS=fs
	CONTINUE=no
	print $0
}

/^(a|ap|d|e|f|k|kde|kdei|l|n|t|tcl|x|xap|y)\/([a-zA-Z0-9_\+]+)-.*: *$/ {
	INPUT=$1
	fs=FS
	FS="/" ; OFS="/"
	$0=INPUT
	FULLPACK=$NF
	FS="-" ; OFS="-"
	$0=FULLPACK
	NF=NF-3
	FS=fs
	CONTINUE=yes
	NAME=$0
}

/^ *([Ad]dded|[Ss]plit|[Rr]enamed|[Mm]oved|[Nn]ame [Cc]hange|NAME CHANGE).*/ {
	if ( CONTINUE==yes ) {
		print NAME
	}
	CONTINUE=no
}
