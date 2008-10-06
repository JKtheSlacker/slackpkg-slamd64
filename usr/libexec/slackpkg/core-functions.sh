#========================================================================
#
# PROGRAM FUNCTIONS
#

# Clean-up tmp and lock files
#
function cleanup() {
	if [ -e $TMPDIR/error.log ]; then
	        echo -e "         
\n==============================================================================
WARNING!        WARNING!        WARNING!        WARNING!        WARNING!
==============================================================================
One or more errors occurred while slackpkg was running:                       
"
		cat $TMPDIR/error.log
		echo -e "
=============================================================================="
	fi    
	echo
	if [ "$DELALL" = "on" ] && [ "$NAMEPKG" != "" ]; then
		rm $TEMP/$NAMEPKG &>/dev/null
	fi		
	( rm -f /var/lock/slackpkg.$$ && rm -rf $TMPDIR ) &>/dev/null
	exit
}
trap 'cleanup' 2 14 15 		# trap CTRL+C and kill

# Syntax Checking
#
function system_checkup() {
	# Check if the config files are updated to the new slackpkg version
	#
	if [ "$WORKDIR" = "" ]; then
		echo -e "\
\nYou need to upgrade your slackpkg.conf.\n\
This is a new slackpkg version and many changes happened in config files.\n\
In ${CONF}/slackpkg.conf.new, there is a sample of the new configuration.\n\
\nAfter updating your configuration file, run: slackpkg update\n" 
		cleanup
	fi

	# Checking if another instance of slackpkg is running
	#
	if [ "$(ls /var/lock/slackpkg.* 2>/dev/null)" ] && \
		[ "$CMD" != "search" ]; then
		echo -e "\
\nAnother instance of slackpkg is running. If this is not correct, you can\n\
remove /var/lock/slackpkg.* files and run slackpkg again.\n"
		cleanup
	else        
		ls /var/lock/slackpkg.* &>/dev/null || \
			touch /var/lock/slackpkg.$$
	fi

	# Checking if the we can create TMPDIR
	#
	if [ "$TMPDIR" = "FAILED" ]; then
		echo -e "\
\nA problem was encountered writing to slackpkg's temporary dir in /tmp.\n\
Check to ensure you have permissions to write in /tmp and make sure the\n\
filesystem is not out of free space.  Run slackpkg again after correcting\n\
the problem.\n"
		cleanup
	fi

	# Checking if is the first time running slackpkg
	#                                               
	if ! [ -f ${WORKDIR}/pkglist ] && [ "$CMD" != "update" ]; then
		echo -e "\
\nThis appears to be the first time you have run slackpkg.\n\
Before you install|upgrade|reinstall anything, you need to uncomment\n\
ONE mirror in ${CONF}/mirrors and run:\n\n\
\t# slackpkg update\n\n\
You can see more information about slackpkg functions in slackpkg manpage."
		cleanup
	fi                                                      


	# Checking if /etc/slackpkg/mirrors are in correct syntax.
	#                                                         
	if [ "$SOURCE" = "" ]; then
		echo -e "\
\nYou do not have any mirror selected in ${CONF}/mirrors\n\
Please edit that file and uncomment ONE mirror.  Slackpkg\n\
only works with ONE mirror selected.\n"
		cleanup
	else
		COUNT=$(echo $SOURCE | wc -w | tr -d " ")
		if [ "$COUNT" != "1" ]; then
			echo -e "\n\
Slackpkg only works with ONE mirror selected.  Please edit your\n\
${CONF}/mirrors and comment all but one line - two or more\n\
mirrors uncommented is not valid syntax.\n"
			cleanup
		fi
	fi

	# It will check if the mirror selected are ftp.slackware.com
	# if set to "ftp.slackware.com" tell the user to choose another
	#
	if echo ${SOURCE} | grep "^ftp://ftp.slackware.com" &>/dev/null ; then
		echo -e "\n\
Please use one of the mirrors.\n\
ftp.slackware.com should be reserved so that the\n\
official mirrors can be kept up-to-date.\n"
		cleanup
	fi

	# Checking if the user has the permissions to install/upgrade/update
	#                                                                    
	if [ "$(id -u)" != "0" ] && [ "$CMD" != "search" ] && [ "$CMD" != "info" ]; then
		echo -e "\n\
Only root can install, upgrade, or remove packages.\n\
Please log in as root or contact your system administrator.\n"
		cleanup
	fi          

	# Check if the mirror are local (cdrom or file)
	#
	MEDIA=$(echo ${SOURCE} | cut -f1 -d:)
	if [ "$MEDIA" = "cdrom" ] || [ "$MEDIA" = "file" ] || \
	   [ "$MEDIA" = "local" ]; then
		SOURCE=/$(echo ${SOURCE} | cut -f3- -d/)
		LOCAL=1
	fi

	# Check if the "which" command is there
	if ! which which 1>/dev/null 2>/dev/null ; then
		echo -e "\n\
No 'which' command found, please install it if you want to\n\
use slackpkg.\n"
		cleanup
	fi

	# Check if we have md5sum in the PATH. Without md5sum, disables
	# md5sum checks
	#
	if ! [ $(which md5sum 2>/dev/null) ]; then
		CHECKPKG=off
	elif ! [ -f ${WORKDIR}/CHECKSUMS.md5 ] && \
		[ "$CMD" != "update" ] && \
		[ "$CHECKPKG" = "on" ]; then
		echo -e "\n\
No CHECKSUMS.md5 found!  Please disable md5sums checking\n\
on your ${CONF}/slackpkg.conf or run slackpkg update\n\
to download a new CHECKSUMS.md5 file.\n"
		cleanup
	fi

	# Check if awk is installed
	#
	if ! [ "$(which awk 2>/dev/null)" ]; then
		echo -e "\n\
awk package not found! Please install awk before you run slackpkg,\n\
as slackpkg cannot function without awk.\n"
		cleanup
	fi

	# Check if gpg is enabled but no GPG command are found.
	#
	if ! [ "$(which gpg 2>/dev/null)" ] && [ "${CHECKGPG}" = "on" ]; then
		CHECKGPG=off
		echo -e "\n\
gpg package not found!  Please disable GPG in ${CONF}/slackpkg.conf or install\n\
the gnupg package.\n\n\
To disable GPG, edit slackpkg.conf and change the value of the CHECKGPG variable\n\
to "off" - you can see an example in the original slackpkg.conf.new file distributed\n\
with slackpkg.\n"
		sleep 5
	fi 

	# Check if the Slackware GPG key are found in the system
	#                                                       
	GPGFIRSTTIME="$(gpg --list-keys \"$SLACKKEY\" 2>/dev/null \
			| grep -c "$SLACKKEY")"
	if [ "$GPGFIRSTTIME" = "0" ] && [ "$CMD" != "search" ] && [ "$CMD" != "info" ] && \
			[ "$CMD" != "update" ] && [ "$CHECKGPG" = "on" ]; then
		echo -e "\n\
You need the GPG key of $SLACKKEY.\n\
To download and install that key, run:\n\n\
\t# slackpkg update gpg\n\n\
You can disable GPG checking too, but it is not a good idea.\n\
To disable GPG, edit slackpkg.conf and change the value of the CHECKGPG variable\n\
to "off" - you can see an example in the original slackpkg.conf.new file distributed\n\
with slackpkg.\n"
		cleanup
	fi

	if [ "$BATCH" = "on" ] || [ "$BATCH" = "ON" ]; then
		DIALOG=off
		MORE=cat
		if [ "$DEFAULT_ANSWER" = "" ]; then
			DEFAULT_ANSWER=n
		fi
	else
		MORE=more
	fi
	echo 
}

# Got the name of a package, without version-arch-release data
#
function cutpkg() {
	echo ${1/.tgz/} | awk -F- 'OFS="-" { 
				if ( NF > 3 ) { 
					NF=NF-3
					print $0 
				} else {
					print $0
				}
			}'
}

# Show the slackpkg usage
#
function usage() {
	echo -e "\
slackpkg - version $VERSION\n\
\nUsage: \tslackpkg update [gpg]\t\tdownload and update files and 
\t\t\t\t\tpackage indexes
\tslackpkg install package\tdownload and install packages 
\tslackpkg upgrade package\tdownload and upgrade packages
\tslackpkg reinstall package\tsame as install, but for packages 
\t\t\t\t\talready installed
\tslackpkg remove package\t\tremove installed packages
\tslackpkg clean-system\t\tremove all packages which are not 
\t\t\t\t\tpresent in the official Slackware 
\t\t\t\t\tpackage set. Good to keep the house
\t\t\t\t\tin order
\tslackpkg upgrade-all\t\tsync all packages installed in your 
\t\t\t\t\tmachine with the selected mirror. This
\t\t\t\t\tis the "correct" way to upgrade all of 
\t\t\t\t\tyour machine.
\tslackpkg install-new\t\tinstall packages which are added to
\t\t\t\t\tthe official Slackware package set.
\t\t\t\t\tRun this if you are upgrading to another
\t\t\t\t\tSlackware version or using "current".
\tslackpkg blacklist\t\tBlacklist a package. Blacklisted
\t\t\t\t\tpackages cannot be upgraded, installed,
\t\t\t\t\tor reinstalled by slackpkg
\tslackpkg download\t\tOnly download (do not install) a package
\tslackpkg info package\t\tShow package information 
\t\t\t\t\t(works with only ONE package)
\tslackpkg search file\t\tSearch for a specific file in the
\t\t\t\t\tentire package collection
\tslackpkg new-config\t\tSearch for new configuration files and
\t\t\t\t\task to user what to do with them.
\nYou can see more information about slackpkg usage and some examples
in slackpkg's manpage. You can use partial package names (such as x11
instead x11-devel, x11-docs, etc), or even Slackware series
(such as "n","ap","xap",etc) when searching for packages.
"
	cleanup
}

# Verify if the package was corrupted by checking md5sum
#
function checkpkg() {
	local MD5ORIGINAL
	local MD5DOWNLOAD

	MD5ORIGINAL=$(grep "/${NAMEPKG}$" ${WORKDIR}/CHECKSUMS.md5| cut -f1 -d \ )
	MD5DOWNLOAD=$(md5sum ${TEMP}/${1} | cut -f1 -d \ )
	if [ "$MD5ORIGINAL" = "$MD5DOWNLOAD" ]; then
		echo 1 
	else
		echo 0 
	fi
}

function checkgpg() {
	gpg --verify ${TEMP}/${1}.asc ${TEMP}/${1} 2>/dev/null && echo "1" || echo "0"
}


function checkblacklist {
        local i
        local BLKNAME="${PKGDATA[1]}"

        for i in 2 3 4; do
                if grep -qx "${BLKNAME}" ${CONF}/blacklist ; then
                        return 0
                fi
                BLKNAME="${BLKNAME}-${PKGDATA[$i]}"
        done
        if grep -qx "${PKGDATA[6]/./}" ${CONF}/blacklist ; then
		return 0
	else
        	return 1
	fi
}

function givepriority {
        local DIR
        local ARGUMENT=$1
	local PKGDATA

	unset NAME
        unset FULLNAME
	unset PKGDATA
	
        for DIR in $FIRST $SECOND $THIRD $FOURTH $FIFTH ; do
		[ "$PKGDATA" ] && break
                PKGDATA=( $(grep "^${DIR} ${ARGUMENT} " ${WORKDIR}/pkglist) )
                if [ "$PKGDATA" ]; then
                        checkblacklist
                        if [ "$?" = "1" ]; then
				NAME=${PKGDATA[1]}
                                FULLNAME=$(echo "${PKGDATA[5]}")
			else
				unset PKGDATA
				unset FULLNAME
				unset NAME
                        fi
                fi
        done
}


# Function to make install/reinstall/upgrade lists
#
function makelist() {
	local ARGUMENT
	local i
	local VRFY

	INPUTLIST=$@

	ls -1 /var/log/packages/* | awk -f /usr/libexec/slackpkg/pkglist.awk > ${TMPDIR}/tmplist

	case "$CMD" in
		clean-system)
			echo -n "Looking for packages to remove. Please wait... "
		;;
		upgrade-all)
			echo -n "Looking for packages to upgrade. Please wait... "
		;;
		install-new)
			echo -n "Looking for NEW packages to install. Please wait... "
		;;
		*)
			echo -n "Looking for $(echo $INPUTLIST | tr -d '\\') in package list. Please wait... "
		;;
	esac

	case "$CMD" in
		download)
			for ARGUMENT in $(echo $INPUTLIST); do
				for i in $(grep -w -- "${ARGUMENT}" ${WORKDIR}/pkglist | cut -f2 -d\  | sort -u); do
					LIST="$LIST $(grep " ${i} " ${WORKDIR}/pkglist | cut -f6 -d \ )"
				done
				LIST="$(echo -e $LIST | sort -u)"
			done
		;;
		blacklist)
			for ARGUMENT in $(echo $INPUTLIST); do
				for i in $(cat ${WORKDIR}/pkglist ${TMPDIR}/tmplist | \
						grep -w -- "${ARGUMENT}" | cut -f2 -d\  | sort -u); do
					grep -qx "${i}" ${CONF}/blacklist || LIST="$LIST $i"
				done
			done
		;;
		install|upgrade|reinstall)
			for ARGUMENT in $(echo $INPUTLIST); do
				for i in $(grep -w -- "${ARGUMENT}" ${WORKDIR}/pkglist | cut -f2 -d\  | sort -u); do
					givepriority $i
					[ ! "$FULLNAME" ] && continue

					case $CMD in
						'upgrade')
							VRFY=$(cut -f6 -d\  ${TMPDIR}/tmplist | \
							      grep -x "${NAME}-[^-]\+-\(noarch\|fw\|${ARCH}\)-[^-]\+")
							[ "${FULLNAME}" != "${VRFY}" ]  && \
										[ "${VRFY}" ] && \
								LIST="$LIST ${FULLNAME}"
						;;
						'install')
							grep -q " ${NAME} " ${TMPDIR}/tmplist || \
								LIST="$LIST ${FULLNAME}"
						;;
						'reinstall')
							grep -q " ${FULLNAME} " ${TMPDIR}/tmplist && \
								LIST="$LIST ${FULLNAME}"
						;;
					esac
				done
			done
		;;
		remove)
			for ARGUMENT in $(echo $INPUTLIST); do
				for i in $(cat ${WORKDIR}/pkglist ${TMPDIR}/tmplist | \
					  	grep -w -- "${ARGUMENT}" | cut -f6 -d\  | sort -u); do
					PKGDATA=( $(grep -w -- "$i" ${TMPDIR}/tmplist) )
					[ ! "$PKGDATA" ] && continue
					checkblacklist
					LIST="$LIST ${PKGDATA[5]}" 
					unset PKGDATA
				done
			done
		;;
		clean-system)
	                for i in $(cut -f6 -d\  ${TMPDIR}/tmplist); do
				NAME=$(cutpkg $i)
				if [ $(cut -f2 -d\  ${WORKDIR}/pkglist |grep -cx "${NAME}") = "0" ] &&
					[ $(grep -cx "${NAME}" $CONF/blacklist) = 0 ]; then
					LIST="$LIST $i"
                        	fi
                	done
		;;
		upgrade-all)
			for i in $(cut -f2 -d\  ${TMPDIR}/tmplist); do

				givepriority ${i}
				[ ! "$FULLNAME" ] && continue

				VRFY=$(cut -f6 -d\  ${TMPDIR}/tmplist | grep -x "${NAME}-[^-]\+-\(noarch\|fw\|${ARCH}\)-[^-]\+")
				[ "${FULLNAME}" != "${VRFY}" ]  && \
							[ "${VRFY}" ] && \
					LIST="$LIST ${FULLNAME}"
			done
		;;
		install-new)
			for i in $(awk -f /usr/libexec/slackpkg/install-new.awk ${WORKDIR}/ChangeLog.txt |\
				  sort -u ) dialog aaa_terminfo fontconfig \
				ntfs-3g ghostscript wqy-zenhei-font-ttf \
				xbacklight xf86-video-geode ; do
	
				givepriority $i
				[ ! "$FULLNAME" ] && continue
				
				grep -q " ${NAME} " ${TMPDIR}/tmplist || \
					LIST="$LIST ${FULLNAME}"
			done
		;;
	esac
	LIST=$(echo -e $LIST | tr \  "\n" | uniq )
	echo -e "DONE\n"
}

# Function to count total of packages
#
function countpkg() {
	local COUNTPKG=$(echo -e "$1" | wc -w)

	if [ "$COUNTPKG" != "0" ]; then
		echo -e "Total package(s): $COUNTPKG\n"
	fi
}

function answer() {
	if [ "$BATCH" = "on" ]; then
		ANSWER="$DEFAULT_ANSWER"
		echo $DEFAULT_ANSWER
	else
		read ANSWER
	fi
}

# Show the lists and asks if the user want to proceed with that action
# Return accepted list in $SHOWLIST
#
function showlist() {
	local ANSWER
	local i

	for i in $1; do echo $i; done | $MORE 
	echo
	countpkg "$1"
	echo -e "Do you wish to $2 selected packages (Y/n)? \c"
	answer
	if [ "$ANSWER" = "N" -o "$ANSWER" = "n" ]; then
		cleanup
	else
		SHOWLIST="$1"
		continue
	fi
}

function getfile() {
        if [ "$LOCAL" = "1" ]; then
                echo -e "\t\t\tCopying $1..."
                cp ${SOURCE}$1 $2 2>/dev/null
        else
                echo -e "\t\t\tDownloading $1..."
                wget ${WGETFLAGS} ${SOURCE}$1 -O $2
        fi
}                                                       

# Function to download the correct package and many "checks"
#
function getpkg() {
	local ISOK="1"
	local ERROR=""
	local PKGNAME
	local FULLPATH
	local NAMEPKG

	PKGNAME=( $(grep -w -m 1 -- "$1" ${WORKDIR}/pkglist) )
	NAMEPKG=${PKGNAME[5]}
	FULLPATH=${PKGNAME[6]}

	if ! [ -e ${TEMP}/${NAMEPKG} ]; then
		echo -e "\nPackage: $1"
		# Check if the mirror are local, if is local, copy files 
		# to TEMP else, download packages from remote host and 
		# put then in TEMP
		#
		if [ "${LOCAL}" = "1" ]; then 
                	echo -e "\tCopying $NAMEPKG..."
			cp ${SOURCE}${FULLPATH}/${NAMEPKG} ${TEMP}
			if [ "$CHECKGPG" = "on" ]; then
				cp ${SOURCE}${FULLPATH}/${NAMEPKG}.asc ${TEMP}
			fi
		else
                	echo -e "\tDownloading $NAMEPKG..."
			wget ${WGETFLAGS} -P ${TEMP} -nd ${SOURCE}${FULLPATH}/${NAMEPKG}
			if [ "$CHECKGPG" = "on" ]; then
				wget ${WGETFLAGS} -P ${TEMP} -nd ${SOURCE}${FULLPATH}/${NAMEPKG}.asc
			fi
		fi

		if ! [ -e $TEMP/$1 ]; then
			ERROR="Not found"
			ISOK="0"
			echo -e "${NAMEPKG}:\t$ERROR" >> $TMPDIR/error.log
		fi
	else
		echo -e "\tPackage $1 is already in cache - not downloading" 
	fi

	# If MD5SUM checks are enabled in slackpkg.conf, check the
	# packages md5sum to detect if they are corrupt or not
	#
	if [ "$CHECKPKG" = "on" ] && [ "$ISOK" = "1" ]; then
		ISOK=$(checkpkg $1)
		if [ "$ISOK" = "0" ]; then 
			ERROR="md5sum"
			echo -e "${NAMEPKG}:\t$ERROR" >> $TMPDIR/error.log
		fi
	fi

	# Check the package against its .asc. If you don't like this
	# disable GPG checking in /etc/slackpkg/slackpkg.conf
	#
	if [ "$CHECKGPG" = "on" ] && [ "$ISOK" = "1" ]; then
		ISOK=$(checkgpg $1)
		if [ "$ISOK" = "0" ]; then 
			ERROR="gpg"
			echo -e "${NAMEPKG}:\t$ERROR" >> $TMPDIR/error.log
		fi
	fi

	if [ "$ISOK" = "1" ]; then
		case $2 in
			installpkg)
				echo -e "\tInstalling ${1/.tgz/}..."
			;;
			upgradepkg)
				echo -e "\tUpgrading ${1/.tgz/}..."
			;;
			*)
				echo -e "\c"
			;;
		esac	
		( cd $TEMP && $2 $1 )
	else 
		rm $TEMP/$1 2>/dev/null
		echo -e "\tERROR - Package not installed! $ERROR error!" 
	fi

	# If DELALL is checked, all downloaded files will be erased
	# after installed/upgraded/reinstalled
	#
	if [ "$DELALL" = "on" ]; then
		rm $TEMP/$1 $TEMP/${1}.asc 2>/dev/null
	fi		
}

# Main logic to download and format package list, md5 etc.
#
function updatefilelists()
{
	if ! [ -e ${WORKDIR}/ChangeLog.txt ]; then
		touch ${WORKDIR}/ChangeLog.txt
	fi

	echo -e "\tDownloading..."
	#
	# Download ChangeLog.txt first of all and test if it's equal
	# or different from our already existent ChangeLog.txt 
	#
	getfile ChangeLog.txt $TMPDIR/ChangeLog.txt
	if ! grep -q "[a-z]" $TMPDIR/ChangeLog.txt ; then
		echo -e "\
\nError downloading from $SOURCE.\n\
Please, check your mirror and try again."
		cleanup
	fi

	if diff --brief ${WORKDIR}/ChangeLog.txt $TMPDIR/ChangeLog.txt ; then
		echo -e "\
\n\t\tNo changes in ChangeLog.txt between your last update and now.\n\
\t\tDo you really want to download all other files (y/N)? \c"
		answer
		if [ "$ANSWER" != "Y" ] && [ "$ANSWER" != "y" ]; then
			cleanup
		fi
	fi
	echo
	cp $TMPDIR/ChangeLog.txt ${WORKDIR}/ChangeLog.txt

	#
	# Download MANIFEST, FILELIST.TXT and CHECKSUMS.md5
	#

	# That will be download MANIFEST.bz2 files
	#
	echo -e "\t\tList of all files"
	for i in $FIRST $SECOND $THIRD $FOURTH $FIFTH ; do 
		getfile ${i}/MANIFEST.bz2 $TMPDIR/${i}-MANIFEST.bz2 && \
			DIRS="$DIRS $i"
	done

	echo -e "\t\tPackage List"
	getfile FILELIST.TXT $TMPDIR/FILELIST.TXT

	if [ "$CHECKPKG" = "on" ]; then
		echo -e "\t\tChecksums"
		getfile CHECKSUMS.md5 ${TMPDIR}/CHECKSUMS.md5
	fi
	cp $TMPDIR/CHECKSUMS.md5 $WORKDIR/CHECKSUMS.md5
		
	# Download all PACKAGES.TXT files
	# 
	echo -e "\t\tPackage descriptions"
	for i in $DIRS; do
		getfile ${i}/PACKAGES.TXT $TMPDIR/${i}-PACKAGES.TXT
	done

	# Format FILELIST.TXT
	#
	echo -e "\tFormatting lists to slackpkg style..."
	echo -e "\t\tPackage List"
	grep "\.tgz" $TMPDIR/FILELIST.TXT| \
		awk -f /usr/libexec/slackpkg/pkglist.awk | \
		sed -e 's/^M//g' > ${TMPDIR}/pkglist
	cp ${TMPDIR}/pkglist ${WORKDIR}/pkglist		

	# Format MANIFEST
	#
		
	# bunzip and concatenate all MANIFEST files
	#
	MANFILES=""
	for i in $DIRS; do
		bunzip2 -c $TMPDIR/${i}-MANIFEST.bz2 | awk -f /usr/libexec/slackpkg/filelist.awk | \
			gzip > ${TMPDIR}/${i}-filelist.gz
	done
	cp ${TMPDIR}/*-filelist.gz ${WORKDIR}/

	if [ -r ${WORKDIR}/filelist.gz ]; then
		rm ${WORKDIR}/filelist.gz
		ln -s ${WORKDIR}/${MAIN}-filelist.gz ${WORKDIR}/filelist.gz
	fi

	# Concatenate PACKAGE.TXT files
	#
	echo -e "\t\tPackage descriptions"
	for i in $DIRS; do
		cat $TMPDIR/${i}-PACKAGES.TXT >> $TMPDIR/PACKAGES.TXT
	done
	cp $TMPDIR/PACKAGES.TXT ${WORKDIR}/PACKAGES.TXT
}

function sanity_check() {
	local REVNAME
	local i
	local FILES
	local DOUBLEFILES
	local ANSWER

	for i in $(ls -1 /var/log/packages | \
		egrep -- "^.*-(${ARCH}|fw|noarch)-[^-]+-upgraded"); do
		REVNAME=$(echo ${i} | awk -F'-upgraded' '{ print $1 }')
		mv /var/log/packages/${i} /var/log/packages/${REVNAME}
		mv /var/log/scripts/${i} /var/log/scripts/${REVNAME}
	done 
	for i in $(ls -1 /var/log/packages | egrep "^.*-(${ARCH}|fw|noarch)-[^-]+$"); do
		cutpkg $i
	done | sort > $TMPDIR/list1
	cat $TMPDIR/list1 | uniq > $TMPDIR/list2
	FILES="$(diff $TMPDIR/list1 $TMPDIR/list2 | grep '<' | cut -f2 -d\ )"
	if [ "$FILES" != "" ]; then
		for i in $FILES ; do
			grep -qx "${i}" ${CONF}/blacklist && continue
			DOUBLEFILES="$DOUBLEFILES $i"
		done
		unset FILES
	fi
	if [ "$DOUBLEFILES" != "" ]; then
		echo -e "\
You have a broken /var/log/packages - with two versions of the same package.\n\
The list of packages duplicated in your machine are shown below, but don't\n\
worry about this list - when you select your action, slackpkg will show a\n\
better list:\n"
		for i in $DOUBLEFILES ; do
			ls -1 /var/log/packages |\
				egrep -i -- "^${i}-[^-]+-(${ARCH}|fw|noarch)-"
		done
		echo -ne "\n\
You can (B)lacklist, (R)emove, or (I)gnore these packages.\n\
Select your action (B/R/I): "
		read ANSWER
		echo
		case "$ANSWER" in
			B|b)
				showlist "$DOUBLEFILES" blacklist
				blacklist_pkg
			;;
			R|r)
				for i in $DOUBLEFILES ; do
					FILE=$(ls -1 /var/log/packages |\
						egrep -i -- "^${i}-[^-]+-(${ARCH}|fw|noarch)-")
					FILES="$FILES $FILE"
				done
				showlist "$FILES" remove
				remove_pkg
			;;
			*)
				echo -e "\n\
Okay - slackpkg won't do anything now, but please, do something to fix it.\n"
				cleanup
			;;
		esac
	fi
}	

function blacklist_pkg() {
	echo $SHOWLIST | tr ' ' "\n" >> ${CONF}/blacklist

	echo -e "\nPackages added to your blacklist.\n\
If you want to remove those packages, edit ${CONF}/blacklist.\n"
}

function remove_pkg() {
	local i

	for i in $SHOWLIST; do
		echo -e "\nPackage: $i"
		echo -e "\tRemoving... "
		removepkg $i
        done
}

function upgrade_pkg() {
	local i

	if [ "$DOWNLOAD_ALL" = "on" ]; then
		OLDDEL="$DELALL"
		DELALL="off"
		for i in $SHOWLIST; do
			getpkg $i true
		done
		DELALL="$OLDDEL"
	fi
	for i in $SHOWLIST; do
		getpkg $i upgradepkg Upgrading
	done
}

function install_pkg() {
	local i

	if [ "$DOWNLOAD_ALL" = "on" ]; then
		OLDDEL="$DELALL"
		DELALL="off"
		for i in $SHOWLIST; do
			getpkg $i true
		done
		DELALL="$OLDDEL"
	fi
	for i in $SHOWLIST; do
		getpkg $i installpkg Installing
	done
}
