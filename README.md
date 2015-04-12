Original at <http://www.timedicer.co.uk/programs/help/dellmont-credit-checker.sh.php>

#dellmont-credit-checker v4.3.4 [01 Oct 2014] by Dominic

#Description
GNU/Linux program to notify if credit on one or more Dellmont/Finarea/Betamax voip provider accounts is running low. Once successfully tested it can be run as daily cron job with **-q** option and **-m email_address** option so that an email is generated when action to top up credit on the account is required. Can also run under MS Windows using Cygwin (<http://www.cygwin.com/>), or can be run as CGI job on Linux/Apache webserver.

#Usage
```dellmont-credit-checker.sh [option]```

#Conffile
A conffile should be in the same directory as **dellmont-credit-checker.sh** with name **dellmont-credit-checker.conf**, or if elsewhere or differently named then be specified by option **-f**, and should contain one or more lines giving the Dellmont/Finarea/Betamax account details in the form:

```website username password [test_credit_level_in_cents] [credit_reduction_in_cents] [credit_recordfile]```

where the **test_credit_level_in_cents** is >=100 or 0 (0 means 'never send email'). If you don't specify a **test_credit_level_in_cents** then the current credit level is always displayed (but no email is ever sent).

If you specify them, the **credit_reduction** and **credit_recordfile** work together to perform an additional test. The program will record in **credit_recordfile** the amount of credit for the given portal each time it is run, and notify you if the credit has reduced since the last time by more than the **credit_reduction**. This can be useful to warn you of unusual activity on the account or of a change in tariffs that is significant for you. Set the **credit_reduction_in_cents** to a level that is more than you would expect to see consumed between consecutive (e.g. daily) runs of **dellmont-credit-checker.sh** e.g. 2000 (for 20 euros/day or 20 dollars/day).

Here's an example single-line conffile to generate a warning email if the credit on the <www.voipdiscount.com> account falls below 3 euros (or dollars):

```www.voipdiscount.com myaccount mypassword 300```

#CGI_Usage
Here is an example of how you could use **dellmont-credit-checker.sh** on your own (presumably internal) website (with CGI configured appropriately on your webserver):

http://www.mywebsite.com/dellmont-credit-checker.sh?options=-vf%20/path/to/my_conf_file.conf%20-m%20me@mymailaddress.com

#Options

- -c [path] - save captcha images (if any) at path (default is current path)
- -d debug - be very verbose and retain temporary files
- -f [path/conffile] - path and name of conffile
- -h show this help and exit
- -l show changelog and exit
- -m [emailaddress] - send any messages about low credit or too-rapidly-falling credit to the specified address (assumes sendmail is available and working)
- -n delete any existing cookies and start over
- -p pause on cookie expiry - wait 2 minutes if cookies have expired before trying to login (because cookies are usually for 24 hours exactly this should allow a second login 24 hours later without requiring new cookies)
- -q quiet
- -s skip if captcha code is requested (e.g. for unattended process)
- -v be more verbose

#Dependencies
awk, bash, coreutils, curl, grep, openssl, sed, [sendmail]

#License
Copyright 2015 Dominic Raferd. Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0. Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

#Portal List
Here is a list of websites / sip portals belonging to and/or operated by Dellmont. To find more, google "is a service from dellmont sarl" (with the quotes). Try a portal with **dellmont-credit-checker.sh** - it might work!

If one of these (or another which you know is run by Dellmont) does not work, run dellmont-credit-checker.sh with -d option and drop me an email attaching the temporary files (two or three per portal, password is stripped out anyway).

	http://www.12voip.com
	http://www.actionvoip.com
	http://www.aptvoip.com
	http://www.bestvoipreselling.com
	http://www.calleasy.com
	http://www.callingcredit.com
	http://www.cheapbuzzer.com
	http://www.cheapvoip.com
	http://www.companycalling.com
	http://www.cosmovoip.com
	http://www.dialcheap.com
	http://www.dialnow.com
	http://www.easycallback.com
	http://www.easyvoip.com
	http://www.freecall.com
	http://www.freevoipdeal.com
	http://www.frynga.com
	http://www.hotvoip.com
	http://www.internetcalls.com
	http://www.intervoip.com
	http://www.jumblo.com
	http://www.justvoip.com
	http://www.lowratevoip.com
	http://www.megavoip.com
	http://www.netappel.fr
	http://www.nonoh.net
	http://www.pennyconnect.com
	http://www.poivy.com
	http://www.powervoip.com
	http://www.rebvoice.com
	http://www.rynga.com
	http://www.scydo.com
	http://www.sipdiscount.com
	http://www.smartvoip.com
	http://www.smsdiscount.com
	http://www.smslisto.com
	http://www.stuntcalls.com
	http://www.supervoip.com
	http://www.telbo.ru
	http://www.voicetrading.com
	http://www.voicetel.co
	http://www.voipblast.com
	http://www.voipblazer.com
	http://www.voipbuster.com
	http://www.voipbusterpro.com
	http://www.voipcheap.co.uk
	http://www.voipcheap.com
	http://www.voipdiscount.com
	http://www.voipgain.com
	http://www.voipmove.com
	http://www.voippro.com
	http://www.voipraider.com
	http://www.voipsmash.com
	http://www.voipstunt.com
	http://www.voipwise.com
	http://www.voipzoom.com
	http://www.webcalldirect.com

A page showing relative prices for many of these sites can be found at <http://backsla.sh/betamax>.

#Changelog
	4.3.4 [01 Oct 2014]: minor bugfix
	4.3.3 [06 Sep 2014]: allow checking of multiple accounts for same provider
	4.3.2 [05 Sep 2014]: improvements to debug text and error output
	4.3.1 [23 Jul 2014]: warning message if no lines found in conf file
	4.3.0 [28 Nov 2013]: use local openssl for decryption (when required) instead of remote web call (thanks Loran)
	4.2.0 [03 Nov 2013]: a lot of changes! Enable CGI usage, remove command-line setting of conffile and email and instead specify these by -f and -m options. Test_credit_level_in_cents is now optional in conffile. Add -v (verbose) option. Squash a bug causing failure if a captcha was requested.
	4.1.1 [01 Nov 2013]: select the reported 'user-agent' randomly from a few
	4.1.0 [01 Nov 2013]: local solution is tried before relying on remote decryption call (thanks Loran)
	4.0.5 [01 Nov 2013]: fix for low-balance or $ currency
	4.0.1 [30 Oct 2013]: fix magictag decryption
	4.0.0 [29 Oct 2013]: works again, requires an additional decryption web call - note a change to conf file format
	3.6 [21 Oct 2013]: works sometimes...
	3.5 [04 Oct 2013]: small tweaks but more reliable I think...
	3.4 [03 Oct 2013]: retrieves captcha image but still not reliable :(
	3.3 [29 Sep 2013]: correction for new credit display code
	3.2 [18 Sep 2013]: corrected for new login procedure
	3.1 [10 Oct 2012]: minor text improvements
	3.0 [27 Aug 2012]: minor text correction for credit reduction
	2.9 [16 Aug 2012]: added optional credit reduction notification
	2.8 [27 Jun 2012]: now works with www.cheapbuzzer.com, added a list of untested Dellmont websites to the help information
	2.7 [25 May 2012]: now works with www.webcalldirect.com
	2.6 [25 May 2012]: fix to show correct credit amounts if >=1000
	2.5 [15 May 2012]: fix for added hidden field on voipdiscount.com
	2.4 [10 May 2012]: improved debug information, voicetrading.com uses method 2, rename previously-named fincheck.sh as dellmont-credit-checker.sh
	2.3 [04 May 2012]: improved debug information
	2.2 [03 May 2012]: further bugfixes
	2.1 [03 May 2012]: now works with www.voipbuster.com
	2.0315 [15 Mar 2012]: allow comment lines (beginning with hash #) in conffile
	2.0313 [13 Mar 2012]: changes to email and help text and changelog layout, and better removal of temporary files
	2.0312 [10 Mar 2012]: improve help, add -l changelog option, remove deprecated methods, add -d debug option, tidy up temporary files, use conffile instead of embedding account data directly in script, first public release
	2.0207 [07 Feb 2012]: new code uses curl for voipdiscount.com
	2.0103 [03 Jan 2012]: no longer uses finchecker.php or fincheck.php unless you select deprecated method; has 2 different approaches, one currently works for voipdiscount, the other for voicetrading.
	1.3 [21 Jun 2010]: stop using external betamax.sh, now uses external fincheck.php via finchecker.php, from http://simong.net/finarea/, using fincheck.phps for fincheck.php; finchecker.php is adapted from example.phps
	1.2 [03 Dec 2008]: uses external betamax.sh script
	1.1 [17 May 2007]: allow the warning_credit_level_in_euros to be set separately on each call
	1.0 [05 Jan 2007]: written by Dominic, it is short and sweet and it works!
