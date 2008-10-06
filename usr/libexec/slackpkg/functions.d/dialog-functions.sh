# Dialog functions
# Original functions from slackpkg modified by Marek Wodzinski (majek@mamy.to)
#
export DIALOG_CANCEL="1"
export DIALOG_ERROR="126"
export DIALOG_ESC="1"
export DIALOG_EXTRA="3"
export DIALOG_HELP="2"
export DIALOG_ITEM_HELP="2"
export DIALOG_OK="0"

# Show the lists and asks if the user want to proceed with that action
# Return accepted list in $SHOWLIST
#
if [ "$DIALOG" = "on" ] || [ "$DIALOG" = "ON" ]; then
	function showlist() {
		if [ "$ONOFF" != "off" ]; then
			ONOFF=on
		fi
		rm -f $TMPDIR/dialog.tmp
		
		if [ "$2" = "upgrade" ]; then
			ls -1 /var/log/packages > $TMPDIR/tmplist
			for i in $1; do
				BASENAME=$(cutpkg $i)
				PKGFOUND=$(grep -m1 -e "^${BASENAME}-[^-]\+-\(noarch\|fw\|${ARCH}\)" $TMPDIR/tmplist).tgz
				echo "$i \"\" $ONOFF \"currently installed: $PKGFOUND\"" >>$TMPDIR/dialog.tmp
			done
			HINT="--item-help"
		else
			for i in $1; do
				echo "$i \"\" $ONOFF" >>$TMPDIR/dialog.tmp
			done
			HINT=""
		fi
		if [ $(wc -c $TMPDIR/dialog.tmp | cut -f1 -d\ ) -ge 19500 ]; then
			mv $TMPDIR/dialog.tmp $TMPDIR/dialog2.tmp
			awk '{ NF=3 ; print $0 }' $TMPDIR/dialog2.tmp > $TMPDIR/dialog.tmp
			HINT=""
		fi
		cat $TMPDIR/dialog.tmp|xargs dialog --title $2 --backtitle "slackpkg $VERSION" $HINT --checklist "Choose packages to $2:" 19 70 13 2>$TMPDIR/dialog.out
		case "$?" in
			0|123)
				dialog --clear
			;;
			1|124|125|126|127)
				dialog --clear
				echo -e "DIALOG ERROR:\n-------------" >> $TMPDIR/error.log
				cat $TMPDIR/dialog.out >> $TMPDIR/error.log
				echo -e "-------------
If you want to continue using slackpkg, disable the DIALOG option in
/etc/slackpkg/slackpkg.conf and try again.

Help us to make slackpkg a better tool - report bugs to the slackpkg
developers" >> $TMPDIR/error.log
				cleanup
			;;
		esac
		SHOWLIST=$(cat $TMPDIR/dialog.out | tr -d \")
		rm -f $TMPDIR/dialog.*
		if [ -z "$SHOWLIST" ]; then
			echo "No packages selected for $2, exiting."
			cleanup
		fi
	}
fi
