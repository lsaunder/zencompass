#!/usr/bin/perl -w
#
# Author: Luke Saunders
# Advance Central Services
# June 2014


use CGI;
use strict;

# capture the called URL
my $cgin = CGI->new;
my $full_url = $cgin->url( -path_info => 1, -query => 1 );

# URL MASK
# cut off the first part of the URL

$full_url =~ s|http://ppr.acsmi.com/cgi-bin/zenfaxOCR.pl\?ZENFAXOCR=||i 
	or die "$0: died at the URL mask. $!";

#RESPOND BACK TO ZENDESK
# give the calling ZenDesk server a response so it knows it was successful
print "Content-type: text/html\n\n";
print <<HTML;
<html>
 <head>
  <title>ACSMI-zendesk-ppr-helper</title>
 </head>
 <body>
  <h1>acsmi-zendesk-ppr-helper</h1>
 </body>
</html>

HTML

# capture the ticket number from the first field and write it to a temp file
# for pickup from zenfaxOCR-response cron task

my $ticketnumber = 0;

if ( $full_url =~ m/\s*(\d*)~/ ) { $ticketnumber = $1; }
else { die "$0: Could not capture ticket number from URL $!"; }

my $dropoffdir = '/usr/lib/cgi-bin/zen-cls-ocr/in/';
my $OCRfilename = "ocrtmp-$ticketnumber.txt";

open ( fOUT, '>', "$dropoffdir$OCRfilename" ) 
	or die "$0: Could not open ocr temp file for writing $!";

print fOUT $full_url;

close fOUT;

exit 0;



	#
	# Example args string:
	# 55 12693820554-1216-173011-473.pdf https://acsmiclass.zendesk.com/attachments/token/dah4n5snua509bd/?name=12693820554-1216-173011-473.pdf
	#