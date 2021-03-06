/^(a|ap|c|d|e|f|k|kde|kdei|l|n|t|tcl|x|xap|y)\/([a-zA-Z0-9_\+]+)-.*:.* ([Ad]dded|[Ss]plit|[Rr]enamed|[Mm]oved|[Nn]ame [Cc]hange|NAME CHANGE|[Ss]witched).*/ {
	INPUT=$1
	fs=FS
	FS="/" ; OFS="/"
	$0=INPUT
	FULLPACK=$NF
	FS="-" ; OFS="-"
	$0=FULLPACK
	if ( NF > 3 ) then
		NF=NF-3
	fi
	FS=fs
	CONTINUE=no
	print $0
}

/^(a|ap|c|d|e|f|k|kde|kdei|l|n|t|tcl|x|xap|y)\/([a-zA-Z0-9_\+]+)-.*: *$/ {
	INPUT=$1
	fs=FS
	FS="/" ; OFS="/"
	$0=INPUT
	FULLPACK=$NF
	FS="-" ; OFS="-"
	$0=FULLPACK
	if ( NF > 3 ) then
		NF=NF-3
	fi
	FS=fs
	CONTINUE=yes
	NAME=$0
}

/^ *([Ad]dded|[Ss]plit|[Rr]enamed|[Mm]oved|[Nn]ame [Cc]hange|NAME CHANGE|[Ss]witched).*/ {
	if ( CONTINUE==yes ) {
		print NAME
	}
	CONTINUE=no
}
