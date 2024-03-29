#!/bin/bash
VERSION="4.5.3 [09 Sep 2019]"
if [ -z "$TEMP" ]; then
	for TEMP in /tmp /var/tmp /var/temp /temp $PWD; do
		[ -d "$TEMP" ] && break
	done
fi

# Define functions for later use
send_message() {
	# single parameter is the message text
	MESSAGE="$1\n\nThis message was generated by $THIS v$VERSION\nhttps://www.timedicer.co.uk/programs/help/$THIS.php"
	MAILNOTSENT=1
	if [ -n "$EMAIL" ]; then
		echo -e "To:$EMAIL\nSubject:$MESSAGE" | sendmail $EMAIL; MAILNOTSENT=$?
	fi
	if [ -z "$QUIET" ]; then
		echo -en "\n\nThis message has "
		[ "$MAILNOTSENT" -gt 0 ] && echo -n "*not* "
		echo -e "been emailed:\n\n$MESSAGE"
	fi
}

check_credit_level() {
	#parameters: website username password warning_credit_level_in_cents/pence
	#example: www.voipdiscount.com myaccount mypassword 200
	unset CREDITCENTS
	# Show website
	if [ -z "$QUIET" ]; then
		[ -n "$VERBOSE" ] && echo -e "\n$1" || echo -n "$1 "
	fi
	# Set up cookiejar
	COOKIEJAR="$TEMP/$THIS-$(id -u)-$1-$2-cookiejar.txt"
	[[ -n $DEBUG ]] && echo "COOKIEJAR: '$COOKIEJAR'"
	if [ -n "$NEWCOOKIEJAR" ]; then
		rm -f "$COOKIEJAR"; touch "$COOKIEJAR"
		[ -z "$QUIET" ] && echo "  deleted any existing cookie jar"
	elif [ ! -f "$COOKIEJAR" ]; then
		touch "$COOKIEJAR"
		[ -n "$VERBOSE" ] && echo "  could not find any existing cookie jar"
	# Check whether cookie is still valid
	else
		FIRSTEXPIRE=$(grep "#Http" "$COOKIEJAR"|grep -v "deleted"|awk '{if ($5!=0) print $5}'|sort -u|head -n 1)
		if [ -n "$FIRSTEXPIRE" ]; then
			if [ $(date +%s) -gt $FIRSTEXPIRE ]; then
				# cookies have expired
				[ -n "$VERBOSE" ] && echo -n "  at least one login cookie has expired"
				if [ -n "$PAUSEONCOOKIEEXPIRY" ]; then
					[ -n "$VERBOSE" ] && echo -n " - waiting 2 minutes [12 dots]:"
					for (( i=1; i<=12; i++)); do sleep 10s; [ -n "$VERBOSE" ] && echo -n "."; done
					[ -n "$VERBOSE" ] && echo -n "done"
				fi
			else
				[ -n "$VERBOSE" ] && echo -n "  all login cookies are still valid"
			fi
			[ -n "$VERBOSE" ] && echo
		else
			[ -n "$VERBOSE" ] && echo "No successful login cookies found in $COOKIEJAR"
		fi
	fi
	if [ -z "$QUIET" ]; then
		[ -n "$VERBOSE" ] && echo -n "  "
		echo -en "$2"
		if [ -n "$4" ]; then
			echo -en " for credit >$4"
			if [ ${#4} -lt 3 -a "$4" != "0" ]; then
				echo -e "\nError: $1 / $2 - can't check for $4 (<100), please supply higher value">&2
				return 1
			fi
		fi
		echo -n ": "
	fi

	# Curl settings
	# -L --location option follows redirects, -i --include adds header information to the output file (makes debug easier)
	
	CURLOPTIONS=( "--user-agent" "\"$USERAGENT\"" "--max-time" "30" "--insecure" "--show-error" "--location" )
	[[ -z "$DEBUG" ]] && CURLOPTIONS+=( "--silent" ) || echo -e "\nCURLOPTIONS       : ${CURLOPTIONS[@]}"
	# Get remote login page with curl
	PAGE1="https://$1/recent_calls${DELLMONTH}"
	for ((RETRIEVELOOP=1; RETRIEVELOOP<=3; RETRIEVELOOP++)); do
		[ $RETRIEVELOOP -gt 1 ] && echo -n "  try $RETRIEVELOOP/3: "
		unset EXPIRED
		curl -b "$COOKIEJAR" -c "$COOKIEJAR" "${CURLOPTIONS[@]}" --fail --include -o "$TEMP/$THIS-$(id -u)-$1-1.htm" "$PAGE1"
		CURLEXIT=$?; [ -n "$DEBUG" ] && echo "Curl exit status  : $CURLEXIT"; [ $CURLEXIT -gt 0 ] && { echo "Curl exit code $CURLEXIT, skipping...">&2; return 2; }
		[ -n "$DEBUG" ] && echo -e "Visited           : $PAGE1\nSaved as          : $TEMP/$THIS-$(id -u)-$1-1.htm\nCookies saved as  : $COOKIEJAR"
		if [ -n "`grep "$2" "$TEMP/$THIS-$(id -u)-$1-1.htm"`" ]; then
			[ -n "$DEBUG" ] && echo "We are already logged in, retrieving info from original page"
			USEFILE=1; break
		fi

		# Locate the correct version of the hidden tag (inside Ajax code, if present)
		unset LINESTART
		HIDDENTAG=$(sed -n '/show_webclient&update_id=&/{s/.*=//;s/".*/\" \//p}' "$TEMP/$THIS-$(id -u)-$1-1.htm")
		if [ -n "$HIDDENTAG" ]; then
			# this works on some portals with Firefox useragent, not with IE or Safari
			# find the form input line which contains the hiddentag
			LINEOFTAG=$(grep -n "$HIDDENTAG" "$TEMP/$THIS-$(id -u)-$1-1.htm"|awk -F: '{printf $1}')
			# find the line of the preceding start of form
			LINESTART=$(awk -v LINEOFTAG=$LINEOFTAG '{if (NR==LINEOFTAG) {printf FORMSTART; exit}; if (match($0,"<form")!=0) FORMSTART=NR}' "$TEMP/$THIS-$(id -u)-$1-1.htm")
			[ -n "$DEBUG" ] && echo -e "Hidden  Tag       : '$HIDDENTAG'\nLine of Tag       : '$LINEOFTAG'\nForm starts @ line: '$LINESTART'"
			[ -z "$LINESTART" ] && echo "An error occurred extracting start of the correct form"
		fi
		if [ -z "$LINESTART" ]; then
			# this decryption method seems to be required for voicetrading.com at least
			[ -n "$DEBUG" ] && echo -e "Unable to find correct version of hidden tag directly, using decryption"
			# extract the encrypted_string and the key
			ENC_AND_KEY=( $(sed -n '/getDecVal/{s/.*getDecValue(//;s/).*//;s/,//;s/"//gp;q}' "$TEMP/$THIS-$(id -u)-$1-1.htm") )
			[ -z "${ENC_AND_KEY[0]}" -o -z "${ENC_AND_KEY[1]}" ] && echo "Unable to extract encrypted magictag and/or key, aborting..." >&2 && return 3
			[ -n "$DEBUG" ] && echo -e "Encrypted Magictag: \"${ENC_AND_KEY[0]}\"\nKey               : \"${ENC_AND_KEY[1]}\"\nDecryption using openssl..."
			# decrypt the magictag by splitting it into 32-character lines then passing to openssl (code by Loran)
			MAGICTAG=$(echo "${ENC_AND_KEY[0]}" | sed 's/.\{32\}/&\n/g;s/\n$//' | openssl enc -d -aes-256-cbc -a -md md5 -k "${ENC_AND_KEY[1]}" 2>/dev/null)
			[ -z "$MAGICTAG" ] && echo "An error occurred extracting magictag, aborting...">&2 && return 4
			[ -n "$DEBUG" ] && echo -e "Decrypted Magictag: \"$MAGICTAG\""
			# get start line of the correct form i.e. div tagged with MAGICTAG
			LINESTART=$(grep -n "$MAGICTAG" "$TEMP/$THIS-$(id -u)-$1-1.htm"|awk -F: '{printf $1; exit}')
			[ -z "$LINESTART" ] && echo "An error occurred extracting start of the correct form using magic key '$MAGICTAG', aborting...">&2 && return 5
			[ -n "$DEBUG" ] && echo -e "Form starts @ line: '$LINESTART' of $TEMP/$THIS-$(id -u)-$1-1.htm"
		fi

		# extract the form info
		sed -n "1,$(( ${LINESTART} -1 ))d;p;/<\/form>/q" "$TEMP/$THIS-$(id -u)-$1-1.htm">"$TEMP/$THIS-$(id -u)-$1-3.htm"
		[ -n "$DEBUG" ] && echo -e "Form saved as     : $TEMP/$THIS-$(id -u)-$1-3.htm"
		# check for a captcha image
		CAPTCHA=$(sed -n '/id="captcha_img/{s/.*src="//;s/".*//p;q}' "$TEMP/$THIS-$(id -u)-$1-3.htm")
		unset HIDDEN
		if [ ${#CAPTCHA} -gt 100 ]; then
			echo -e "\nError extracting CAPTCHA code">&2
			return 6
		elif [ -n "$CAPTCHA" ]; then
			if [ -z "$SKIPONCAPTCHA" ]; then
				[ -n "$DEBUG" ] && echo -e "Retrieving Captcha: $CAPTCHA"
				curl -c "$COOKIEJAR" -b "$COOKIEJAR" "${CURLOPTIONS[@]}" -e "$PAGE1" --fail -o "$CAPTCHAPATH$THIS-$1-captcha.jpeg" $CAPTCHA
				CURLEXIT=$?
				[ -n "$DEBUG" ] && echo "Curl exit status  : $CURLEXIT"
				echo -e "\n  Captcha image saved as $CAPTCHAPATH$THIS-$1-captcha.jpeg"
				read -p "  Please enter Captcha code: " -t 120 </dev/stderr
				[ -z "$REPLY" ] && { echo "Skipping $1 retrieval...">&2; return 7; }
				echo -n "  "
				HIDDEN=" -F \"login[usercode]=$REPLY\""
			else
				[ -n "$QUIET" ] && echo -n "$1: "
				echo "[FAIL] - captcha code requested, try again with -c option"
				rm -f "$COOKIEJAR"
				USEFILE=0
				break
			fi
		fi
		# there are hidden fields with complicated name and data
		HIDDEN+=$(grep -o "<input type=\"hidden\"[^>]*>" "$TEMP/$THIS-$(id -u)-$1-3.htm"|awk -F \" '{for (i=1; i<NF; i++) {if ($i==" name=") printf " -F " $(i+1) "="; if ($i==" value=") printf $(i+1)}}')
		FORMRETURNPAGE=`sed -n '/<form/{s/.*action="\([^"]*\).*/\1/;p;q}' "$TEMP/$THIS-$(id -u)-$1-3.htm"`
		if [ -n "$DEBUG" ]; then
			[ -n "$HIDDEN" ] && echo -e "Hidden fields     : $HIDDEN"
			DEBUGFILE="$TEMP/$THIS-$(id -u)-$1-2d.htm"
			DEBUGCURLEXTRA=" --trace-ascii $DEBUGFILE "
		else
			unset DEBUGCURLEXTRA
		fi
		# Get the form data
		if [ -n "$FORMRETURNPAGE" ]; then
			curl -b "$COOKIEJAR" -c "$COOKIEJAR" "${CURLOPTIONS[@]}" $DEBUGCURLEXTRA -e "$PAGE1" --fail --include -F "login[username]=$2" -F "login[password]=$3" $HIDDEN  -o "$TEMP/$THIS-$(id -u)-$1-2.htm" "$FORMRETURNPAGE"
			CURLEXIT=$?; [ -n "$DEBUG" ] && echo "Curl exit status  : $CURLEXIT"; [ $CURLEXIT -gt 0 ] && { echo "Curl exit code $CURLEXIT, aborting...">&2; return 8; }
			[ -s "$TEMP/$THIS-$(id -u)-$1-2.htm" ] || { echo "Curl failed to save file $TEMP/$THIS-$(id -u)-$1-2.htm, aborting...">&2; return 9; }
			if [ -n "$DEBUG" ]; then
				sed -i "s/$3/\[hidden\]/g" "$DEBUGFILE" # remove password from debug file
				echo -e "Visited           : $FORMRETURNPAGE\nSaved as          : $(ls -l $TEMP/$THIS-$(id -u)-$1-2.htm)\nTrace-ascii output: $DEBUGFILE (password removed)"
			fi
			if [ -n "$(grep "This account has been disabled" "$TEMP/$THIS-$(id -u)-$1-2.htm")" ]; then
				echo "[FAIL] - account disabled"
				USEFILE=0; break
			fi
			EXPIRED=$(grep -o "your session.*expired" "$TEMP/$THIS-$(id -u)-$1-2.htm")
			if [ -n "$EXPIRED" ]; then
				[ -n "$DEBUG" ] && { echo "                    Session expired">&2; USEFILE=0; break; }
				echo "[FAIL] - session expired"
				rm -f "$COOKIEJAR"
				USEFILE=0
			else
				USEFILE=2; break
			fi
		else
			echo "No form data found, unable to obtain credit amount">&2
			USEFILE=0; break
		fi
	done
	if [[ -n $CALLRECORDSDIR && -s "$TEMP/$THIS-$(id -u)-$1-$USEFILE.htm" ]]; then
		CALLRECORDSFILE="$CALLRECORDSDIR/$1-$2.out"
		[[ -n $DEBUG ]] && echo "Appending to $CALLRECORDSFILE:" && ls -l "$CALLRECORDSFILE"
		CRFTMP="$TEMP/$THIS-$(id -u)-$1-callrecords.out"
		if [[ -s $CALLRECORDSFILE ]]; then
			cp -a "$CALLRECORDSFILE" "$CRFTMP" 2>/dev/null
		else
			truncate -s0 $CRFTMP
		fi
		sed -n '/recent-call-list-details/,/date-navigator center/p' "$TEMP/$THIS-$(id -u)-$1-$USEFILE.htm" | sed '/helptip/d;/SIP call/d;/<tr/d;s/.*<td>//;/&nbsp/s/\.//;s/.*&nbsp;//' \
		|sed -e :a -e "/td/N; s/..td..\n/$DELIMITER/; ta" | sed -n "s/Free;/0000/;s/$DELIMITER  *<\/tr>//p" >> "$CRFTMP"
		sed "s/^\([0-9][0-9]\)-\([A-Z][a-z][a-z]\)-\(20[1-9][0-9]\);/\3-\2-\1;/;s/Jan/01/;s/Feb/02/;s/M.r/03/;s/Apr/04/;s/Ma./05/;s/Jun/06/;s/Jul/07/;s/Aug/08/;s/Sep/09/;s/O.t/10/;s/Nov/11/;s/De[^s]/12/" "$CRFTMP"\
		|sort -u > "$CALLRECORDSFILE"
		[[ -n $DEBUG ]] && ls -l $CALLRECORDSFILE || [[ -f "$CRFTMP" ]] && rm -f "$CRFTMP"
	fi

	if [ $USEFILE -gt 0 ]; then
		FREEDAYS=$(sed -n '/class="freedays"/{s/.*class="freedays".//;s/ days.*$//;p}' "$TEMP/$THIS-$(id -u)-$1-$USEFILE.htm")
		CREDITCENTS=$(sed -n '/class="[^"]*balance"/{s/.*pound; //;s/.*euro; //;s/.*\$//;s/<.*//;s/\.//;s/^0*//;p}' "$TEMP/$THIS-$(id -u)-$1-$USEFILE.htm")
	fi
	if [ -n "$DEBUG" ];then
		echo "Credit            : '$CREDITCENTS'"
		[[ -n $FREEDAYS ]] && echo "Freedays          : '$FREEDAYS'"
	else
		# Clean up
		rm -f "$TEMP/$THIS-$(id -u)-$1-"*.htm # note COOKIEJARs are not removed, so cookies can be reused if it is rerun
		[ -z "$4" ] || [ -z "$QUIET" -a -n "$CREDITCENTS" ] && echo -n "$CREDITCENTS"
		[[ -z $QUIET && -n $FREEDAYS ]] && echo -n "  Freedays : $FREEDAYS"
	fi
	if [ -z "$CREDITCENTS" ]; then
		echo "Error: $1 / $2 - CREDITCENTS is blank">&2
		RETURNCODE=11
	elif [ "$CREDITCENTS" -ge 0 -o "$CREDITCENTS" -lt 0 2>&- ]; then
		if [ -n "$6" -a -n "$5" ]; then
			# check for periodic (e.g. daily) change in credit
			if [ -s "$6" ]; then
				local PREVCREDIT=(`tail -n 1 "$6"`)
			else
				local PREVCREDIT=("2000-01-01 00:00 0")
			fi
			echo -e "`date +"%Y-%m-%d %T"`\t$CREDITCENTS">>"$6" 2>/dev/null || echo "Warning: unable to write to $6" >&2
			local CREDITFALL=$((${PREVCREDIT[2]}-$CREDITCENTS))
			[ -n "$DEBUG" ] && echo -en "Previous credit   : '${PREVCREDIT[2]}' at ${PREVCREDIT[0]} ${PREVCREDIT[1]}\nCredit Reduction  : '$CREDITFALL'"
			if [ $CREDITFALL -gt $5 ]; then
				send_message "Credit Reduction Warning - $1\nThe credit on your $1 account '$2' stands at ${CREDITCENTS:0:$((${#CREDITCENTS}-2))}.${CREDITCENTS:(-2):2}, and has fallen by ${CREDITFALL:0:$((${#CREDITFALL}-2))}.${CREDITFALL:(-2):2} since ${PREVCREDIT[0]} ${PREVCREDIT[1]}."
			fi
		fi
		if [ -z "$4" ]; then
			echo
		else
			if [ "$4" != "0" ] && [ "$CREDITCENTS" -lt "$4" ]; then
				send_message "Credit Level Warning - $1\nThe credit on your $1 account '$2' stands at ${CREDITCENTS:0:$((${#CREDITCENTS}-2))}.${CREDITCENTS:(-2):2} - below your specified test level of ${4:0:$((${#4}-2))}.${4:(-2):2}.\nYou can buy more credit at: https://$1/myaccount/"
			elif [ -z "$QUIET" ]; then
				echo  " - ok"
			fi
		fi
		RETURNCODE=0
	else
		echo "Error: $1 / $2 - CREDITCENTS is a non-integer value: '$CREDITCENTS'">&2
		RETURNCODE=13
	fi
	shift 999
	return $RETURNCODE
}

# Start of main script

# Global variables
THIS="`basename $0`"; COLUMNS=$(stty size 2>/dev/null||echo 80); COLUMNS=${COLUMNS##* }
UMASK=177 # all files created are readable/writeable only by current user
DELIMITER=","
unset DELLMONTH

# Check whether script is run as CGI
if [ -n "$SERVER_SOFTWARE" ]; then
	# if being called by CGI, set the content type
	echo -e "Content-type: text/plain\n"
	# extract any options
	OPTS=$(echo "$QUERY_STRING"|sed -n '/options=/{s/.*options=\([^&]*\).*/\1/;s/%20/ /;p}')
	#echo -e "QUERY_STRING: '$QUERY_STRING'\nOPTS: '$OPTS'"
	SKIPONCAPTCHA="y" # for now we have no way to show captcha images when called from CGI script, so prevent it happening..

fi
# Parse commandline switches
while getopts ":dc:f:hlm:M:npr:qst:u:vw" optname $@$OPTS; do
    case "$optname" in
		"c")	CAPTCHAPATH="$OPTARG";;
		"c")	CAPTCHAPATH="$OPTARG";;
		"d")	DEBUG="y";VERBOSE="y";;
		"f")	CONFFILE="$OPTARG";;
		"h")	HELP="y";;
		"l")	CHANGELOG="y";;
		"m")	EMAIL="$OPTARG";;
		"M")	DELLMONTH="$OPTARG";;
		"n")	NEWCOOKIEJAR="y";;
		"p")	PAUSEONCOOKIEEXPIRY="y";;
		"q")	QUIET="y";;
		"r")	CALLRECORDSDIR="$OPTARG";;
		"s")	SKIPONCAPTCHA="y";;
		"t")	DELIMITER="$OPTARG";;
		"u")	UMASK=$OPTARG;;
		"v")	VERBOSE="y";;
		"w")	COLUMNS=30000;; #suppress line-breaking
		"?")	echo "Unknown option $OPTARG"; exit 1;;
		":")	echo "No argument value for option $OPTARG"; exit 1;;
		*)	# Should not occur
			echo "Unknown error while processing options"; exit 1;;
    esac
done
shift $(($OPTIND-1))

# Show debug info
[ -n "$DEBUG" -a -n "$QUERY_STRING" ] && echo -e "QUERY_STRING: '$QUERY_STRING'\nOPTS: '$OPTS'"
# Show author information
[ -z "$QUIET" -o -n "$HELP$CHANGELOG" ] && echo -e "\n$THIS v$VERSION by Dominic\n${THIS//?/=}"

# Show help
if [ -n "$HELP" ]; then
	echo -e "\nGNU/Linux program to notify if credit on one or more \
Dellmont/Finarea/Betamax voip \
provider accounts is running low. Once successfully tested it can be run \
as daily cron job with -q option and -m email_address option \
so that an email is generated when action to top up \
credit on the account is required. Can also run under MS Windows using Cygwin \
(http://www.cygwin.com/), or can be run as CGI job on Linux/Apache webserver.

Usage: `basename $0` [option]

Conffile:
A conffile should be in the same directory as $THIS with name \
$(basename $THIS .sh).conf, or if elsewhere or differently named then be specified by option -f, and should contain one or more lines giving the \
Dellmont/Finarea/Betamax account details in the form:
website username password [test_credit_level_in_cents/pence] [credit_reduction_in_cents/pence] [credit_recordfile]

where the test_credit_level_in_cents/pence is >=100 or 0 (0 means 'never send \
email'). If you don't specify a test_credit_level_in_cents/pence then the \
current credit level is always displayed (but no email is ever sent).

If you specify them, the credit_reduction and credit_recordfile work together \
to perform an additional test. The program will record in credit_recordfile \
the amount of credit for the given portal each time it is run, and notify you \
if the credit has reduced since the last time by more than the \
credit_reduction. This can be useful to warn you of unusual activity on \
the account or of a change in tariffs that is significant for you. \
Set the credit_reduction_in_cents/pence to a level that is more than you \
would expect to see consumed between consecutive (e.g. daily) runs of $THIS \
e.g. 2000 (for 20 euros/day or 20 dollars/day).

Here's an example single-line conffile to generate a warning \
email if the credit \
on the www.voipdiscount.com account falls below 3 euros (or dollars):
    www.voipdiscount.com myaccount mypassword 300

Temporary_Files:
Temporary files are saved with 600 permissions in \$TEMP which is set to a \
standard location, normally /tmp, unless it is already defined (so you can \
define it if you want a special location). Unless run with debug option, \
all such files are deleted after running - except the cookiejar file which \
is retained so it can be reused. (The same cookiejar file is also used, if \
found, by get-vt-cdrs.sh.)

Call Records History:
You can use options -r and -t to download call records and append them to a \
specified file.

CGI_Usage:
Here is an example of how you could use $THIS on your own (presumably \
internal) website (with CGI configured appropriately on your webserver):
http://www.mywebsite.com/$THIS?options=-vf%20/path/to/my_conf_file.conf%20-m%20me@mymailaddress.com

Options:
  -c [path] - save captcha images (if any) at path (default is current path)
  -d  debug - be very verbose and retain temporary files
  -f [path/conffile] - path and name of conffile
  -h  show this help and exit
  -l  show changelog and exit
  -m [emailaddress] - send any messages about low credit or too-rapidly-falling credit to the specified address (assumes sendmail is available and working)
  -M \"[month-year-page]\" - specify a specific earlier month and page for call record history retrieval (with -r option) - format '/MM/YYYY/P'
  -n  delete any existing cookies and start over
  -p  pause on cookie expiry - wait 2 minutes if cookies have expired before \
trying to login (because cookies are usually for 24 hours exactly this should \
allow a second login 24 hours later without requiring new cookies)
  -q  quiet
  -r  [path/file] - specify a directory for call record history files (per \
website and account) - data is appended to any existing files
  -s  skip if captcha code is requested (e.g. for unattended process)
  -t  [char] - if extracting call records (-r), this specifies the field separator character (default comma)
  -u  set umask for any created files (default 177: files are readable/writable only by current user)
  -v  be more verbose

Dependencies: awk, bash, coreutils, curl, grep, openssl, sed, [sendmail], umask

License: Copyright © 2022 Dominic Raferd. Licensed under the Apache License, \
Version 2.0 (the \"License\"); you may not use this file except in compliance \
with the License. You may obtain a copy of the License at \
https://www.apache.org/licenses/LICENSE-2.0. Unless required by applicable \
law or agreed to in writing, software distributed under the License is \
distributed on an \"AS IS\" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY \
KIND, either express or implied. See the License for the specific language \
governing permissions and limitations under the License.

Portal List:
Here is a list of websites / sip portals belonging to and/or operated by \
Dellmont. To find more, google \&quot;is a service from dellmont sarl\&quot; \
(with the quotes). Try a portal with $THIS - it might work!

If one of these (or \
another which you know is run by Dellmont) does not work, run $THIS with -d \
option and drop me an email attaching the temporary files (two or three \
per portal, password is stripped out anyway).

https://www.12voip.com
https://www.actionvoip.com
https://www.aptvoip.com
https://www.bestvoipreselling.com
https://www.calleasy.com
https://www.callingcredit.com
https://www.cheapbuzzer.com
https://www.cheapvoip.com
https://www.cosmovoip.com
https://www.dialcheap.com
https://www.dialnow.com
https://www.discountvoip.co.uk
https://www.easyvoip.com
https://www.freecall.com
https://www.freevoipdeal.com
https://www.frynga.com
https://www.hotvoip.com
https://www.internetcalls.com
https://www.intervoip.com
https://www.jumblo.com
https://www.justvoip.com
https://www.lowratevoip.com
https://www.megavoip.com
https://www.netappel.fr
https://www.nonoh.net
https://www.pennyconnect.com
https://www.poivy.com
https://www.powervoip.com
https://www.rebvoice.com
https://www.rynga.com
https://www.scydo.com
https://www.sipdiscount.com
https://www.smartvoip.com
https://www.smsdiscount.com
https://www.smslisto.com
https://www.stuntcalls.com
https://www.supervoip.com
https://www.voicetrading.com
https://www.voipblast.com
https://www.voipblazer.com
https://www.voipbuster.com
https://www.voipbusterpro.com
https://www.voipcheap.co.uk
https://www.voipcheap.com
https://www.voipdiscount.com
https://www.voipgain.com
https://www.voipmove.com
https://www.voippro.com
https://www.voipraider.com
https://www.voipsmash.com
https://www.voipstunt.com
https://www.voipwise.com
https://www.voipzoom.com
https://www.webcalldirect.com

A page showing relative prices for many of these sites may be found at http://backsla.sh/betamax - it may or may not still be current.
"|fold -s -w $COLUMNS
fi

# Show changelog
if [ -n "$CHANGELOG" ]; then
	[ -n "$HELP" ] && echo "Changelog:" || echo
	echo "\
4.5.3 [09 Sep 2019]: read gpg2-encrypted conf file (if .gpg filename extension)
4.5.2 [15 Aug 2019]: bugfix for freedays, add -M option (kudos: Mathias Rothe)
4.5.1 [12 Aug 2019]: bugfixes, change -r option to set the output directory (not file)
4.5.0 [07 Aug 2019]: add -r and -t options and show Freedays (if any) (kudos: Mathias Rothe)
4.4.6 [16 Jun 2019]: hide openssl 1.1.1 'deprecated key derivation' message when decrypting
4.4.5 [11 Apr 2019]: update to work with pounds sterling (kudos: Mathias Rothe)
4.4.4 [10 Apr 2019]: update to try to work with captcha
4.4.3 [31 Jul 2018]: update to work with OpenSSL 1.1.0g (backwards compatible)
4.4.2 [27 Mar 2017]: add -u option (set umask)
4.4.1 [29 Jun 2016]: rename cookiejar and temporary files to include userid (number) rather than username
4.4.0 [25 Mar 2016]: bugfix
4.3.9 [16 Mar 2016]: bugfix
4.3.8 [15 Mar 2016]: set permissions of all files created to 600, to secure from other users, move cookiejar files back to \$TEMP and rename cookiejar filename to include \$USER so that multiple users do not overwrite one another's cookiejars
4.3.7 [19 Feb 2016]: if the specified credit_recordfile can't be accessed, show warning instead of failing
4.3.6 [08 Feb 2016]: bugfix for credit <100 eurocents
4.3.5 [18 May 2015]: move cookiejar file location to /var/tmp
4.3.4 [01 Oct 2014]: minor bugfix
4.3.3 [06 Sep 2014]: allow checking of multiple accounts for same provider
4.3.2 [05 Sep 2014]: improvements to debug text and error output
4.3.1 [23 Jul 2014]: warning message if no lines found in conf file
4.3.0 [28 Nov 2013]: use local openssl for decryption (when \
required) instead of remote web call (thanks Loran)
4.2.0 [03 Nov 2013]: a lot of changes! Enable CGI usage, remove \
command-line setting of conffile and email and instead specify these by -f \
and -m options. Test_credit_level_in_cents is now optional in conffile. Add \
-v (verbose) option. Squash a bug causing failure if a captcha was requested.
4.1.1 [01 Nov 2013]: select the reported 'user-agent' randomly from a few
4.1.0 [01 Nov 2013]: local solution is tried before relying on remote \
decryption call (thanks Loran)
4.0.5 [01 Nov 2013]: fix for low-balance or $ currency
4.0.1 [30 Oct 2013]: fix magictag decryption
4.0.0 [29 Oct 2013]: works again, requires an additional decryption web call \
- note a change to conf file format
3.6 [21 Oct 2013]: works sometimes...
3.5 [04 Oct 2013]: small tweaks but more reliable I think...
3.4 [03 Oct 2013]: retrieves captcha image but still not reliable :(
3.3 [29 Sep 2013]: correction for new credit display code
3.2 [18 Sep 2013]: corrected for new login procedure
3.1 [10 Oct 2012]: minor text improvements
3.0 [27 Aug 2012]: minor text correction for credit reduction
2.9 [16 Aug 2012]: added optional credit reduction notification
2.8 [27 Jun 2012]: now works with www.cheapbuzzer.com, added \
a list of untested Dellmont websites to the help information
2.7 [25 May 2012]: now works with www.webcalldirect.com
2.6 [25 May 2012]: fix to show correct credit amounts if >=1000
2.5 [15 May 2012]: fix for added hidden field on voipdiscount.com
2.4 [10 May 2012]: improved debug information, voicetrading.com \
uses method 2, rename previously-named fincheck.sh as \
dellmont-credit-checker.sh
2.3 [04 May 2012]: improved debug information
2.2 [03 May 2012]: further bugfixes
2.1 [03 May 2012]: now works with www.voipbuster.com
2.0315 [15 Mar 2012]: allow comment lines (beginning with \
hash #) in conffile
2.0313 [13 Mar 2012]: changes to email and help text and \
changelog layout, and better removal of temporary files
2.0312 [10 Mar 2012]: improve help, add -l changelog option, remove \
deprecated methods, add -d debug option, tidy up temporary files, \
use conffile instead of embedding account data directly in \
script, first public release
2.0207 [07 Feb 2012]: new code uses curl for voipdiscount.com
2.0103 [03 Jan 2012]: no longer uses finchecker.php or fincheck.php \
unless you select \
deprecated method; has 2 different approaches, one currently works for \
voipdiscount, the other for voicetrading.
1.3 [21 Jun 2010]: stop using external betamax.sh, now uses external \
fincheck.php via finchecker.php, from \
http://simong.net/finarea/, using fincheck.phps for fincheck.php; \
finchecker.php is adapted from example.phps
1.2 [03 Dec 2008]: uses external betamax.sh script
1.1 [17 May 2007]: allow the warning_credit_level_in_euros to be set separately on \
each call
1.0 [05 Jan 2007]: written by Dominic, it is short and sweet and it works!
"|fold -sw $COLUMNS
fi

# Exit if help or changelog was asked
[ -n "$HELP$CHANGELOG" ] && exit

# Show debug info
[ -n "$DEBUG" ] && echo -e "Debug mode"

# Ensure that all files created are readable/writeable only by current user
umask $UMASK

# Check for conffile 
if [ -z "$CONFFILE" ]; then
	[ ! -s "$1" ] && CONFFILE="$(echo "$(dirname "$0")/$(basename "$0" .sh).conf")"  || CONFFILE="$1"
fi
[ -n "$DEBUG" ] && echo -e "CONFFILE: '$CONFFILE'\nCALLRECORDSDIR: '$CALLRECORDSDIR'\nDELIMITER: '$DELIMITER'"
[ ! -s "$CONFFILE" ] && echo "Cannot find conf file '$1', aborting">&2 && exit 1
[[ -z $CALLRECORDSDIR || -d $CALLRECORDSDIR ]] || { echo "Can't locate call records directory '$CALLRECORDSDIR', aborting" >&2; exit 1; }
# Print email adress
[ -n "$EMAIL" -a -z "$QUIET" ] && echo -e "Any low credit warnings will be emailed to $EMAIL\n"

# Ensure CAPTCHAPATH ends with a slash, and that the path exists
if [ -n "$CAPTCHAPATH" ];then
	if [ "${CAPTCHAPATH:$(( ${#CAPTCHAPATH} - 1 )): 1}" != "/" ]; then
		CAPTCHAPATH="${CAPTCHAPATH}/"
		[ -n "$DEBUG" ] && echo "CAPTCHAPATH amended to: '$CAPTCHAPATH'"
	fi
	[ -d "$CAPTCHAPATH" ] || { echo "Could not find path '$CAPTCHAPATH', aborting...">&2; exit 1; }
fi

# select (fake) user agent from a few possibles
# skip over Safari and IE because with them we never get the embedded hiddentag
#Mozilla/5.0 (iPad; CPU OS 6_0 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Version/6.0 Mobile/10A5355d Safari/8536.25
#Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/537.13+ (KHTML, like Gecko) Version/5.1.7 Safari/534.57.2
#Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_3) AppleWebKit/534.55.3 (KHTML, like Gecko) Version/5.1.3 Safari/534.53.10
#Mozilla/5.0 (iPad; CPU OS 5_1 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko ) Version/5.1 Mobile/9B176 Safari/7534.48.3
#Mozilla/5.0 (compatible; MSIE 10.6; Windows NT 6.1; Trident/5.0; InfoPath.2; SLCC1; .NET CLR 3.0.4506.2152; .NET CLR 3.5.30729; .NET CLR 2.0.50727) 3gpp-gba UNTRUSTED/1.0
#Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; WOW64; Trident/6.0)
#Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/6.0)
#Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/5.0)
#Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/4.0; InfoPath.2; SV1; .NET CLR 2.0.50727; WOW64)
#Mozilla/5.0 (compatible; MSIE 10.0; Macintosh; Intel Mac OS X 10_7_3; Trident/6.0)
#Mozilla/4.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/5.0)
#Mozilla/1.22 (compatible; MSIE 10.0; Windows 3.1)
echo "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:25.0) Gecko/20100101 Firefox/25.0
Mozilla/5.0 (Macintosh; Intel Mac OS X 10.6; rv:25.0) Gecko/20100101 Firefox/25.0
Mozilla/5.0 (X11; Ubuntu; Linux i686; rv:24.0) Gecko/20100101 Firefox/24.0
Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:24.0) Gecko/20100101 Firefox/24.0
Mozilla/5.0 (Windows NT 6.0; WOW64; rv:24.0) Gecko/20100101 Firefox/24.0
Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:24.0) Gecko/20100101 Firefox/24.0
Mozilla/5.0 (Windows NT 6.2; rv:22.0) Gecko/20130405 Firefox/23.0
Mozilla/5.0 (Windows NT 6.1; WOW64; rv:23.0) Gecko/20130406 Firefox/23.0
Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:23.0) Gecko/20131011 Firefox/23.0
Mozilla/5.0 (Windows NT 6.2; rv:22.0) Gecko/20130405 Firefox/22.0
Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:22.0) Gecko/20130328 Firefox/22.0
Mozilla/5.0 (Windows NT 6.1; rv:22.0) Gecko/20130405 Firefox/22.0
Mozilla/5.0 (Windows NT 6.1; WOW64; rv:22.0) Gecko/20100101 Firefox/22.0" >"$TEMP/$THIS-$(id -u)-$$-useragents.txt"
USERAGENT="$(sort -R "$TEMP/$THIS-$(id -u)-$$-useragents.txt"|head -n 1)"; rm "$TEMP/$THIS-$(id -u)-$$-useragents.txt"
[ -n "$DEBUG" ] && echo "Selected user agent: \"$USERAGENT\""

# Loop through conffile line by line
LINENUM=0; ERRS=0
[[ ${CONFFILE: -4} == ".gpg" ]] && READCONF="gpg2 -d $CONFFILE" || READCONF="cat $CONFFILE"
while read LINE; do
	let LINENUM++
	[ -n "$DEBUG" ] && { echo -n "conffile line $LINENUM   :"; echo "$LINE"|awk '{printf $1 " " $2 "..." }'; }
	if [ -n "$LINE" -a "${LINE:0:1}" != "#" ]; then
		[ -n "$DEBUG" ] && echo -n " - checking"
		check_credit_level $LINE; CERR=$?
		[ $CERR -eq 0 ] || { let ERRS++; echo -n "credit_check_level reported error $CERR for "; echo "$LINE"|awk '{print $1 " " $2 }'; }
	elif [ -n "$DEBUG" ]; then
		echo " - skipping"
	fi
	[ -n "$DEBUG" ] && echo
done < <($READCONF)
[ $LINENUM -eq 0 ] && echo "Could not find any lines in $CONFFILE to process, did you miss putting an EOL?" >&2
[ -n "$DEBUG" ] && echo "Completed with ERRS: '$ERRS'"
exit $ERRS
