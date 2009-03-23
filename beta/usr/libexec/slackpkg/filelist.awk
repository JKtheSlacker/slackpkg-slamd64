BEGIN {
  starting = 1
}

/^\|\|[[:blank:]]+Package:[[:blank:]]+.*-[[:alnum:]_]+-[[:digit:]]+\.tgz$/ {
  if( starting == 1 )
    starting = 0
  else
    printf( "\n" )
  printf( "%s ", $3 )
  show = 1
}

/^\|\|[[:blank:]]+Package:[[:blank:]]+/ && !/tgz/ {
	show = 0
}

/^[-bcdlps][-r][-w][-xsS][-r][-w][-xsS][-r][-w][-xtT][[:space:]]/ {
  if( show == 1 ) {
	printf( "%s ", $6 )
  }
}



END {
  printf( "\n" )
}
