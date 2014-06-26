#!/usr/bin/perl -w
#
# Author: Luke Saunders
# Advance Central Services
# 4/28/2013
# 05/05/14 - customized for zendesk.  

use CGI;
use POSIX;
use strict;

require "./zenxml-functions.pl"; 

# capture the called URL
my $cgin = CGI->new;
my $full_url = $cgin -> url ( -path_info=>1 ,  -query=>1 );

#URL MASK
# cut off the first part of the URL
$full_url =~ s|http://ppr.acsmi.com/cgi-bin/get-zen-attachments.pl\?ATTACHMENTS=||i || die ;

my $clean_url = my_to_ascii ( $full_url );

# put the remaining arguments into an array 
my @args = split( '~' , $clean_url );

my $zenID = shift @args;
my $mactiveAdNumber = shift @args;
my $customerName = shift @args;
my $BWorColor = shift @args;

$customerName =~ s/^\s+|,?\s+.+$//g;  # just use the first literal of the name.

my @images = ();

for my $imagefile ( @args ) {
	push ( @images, $imagefile ) if ( $imagefile =~ m/(jpe?g|png|pdf|tiff?)$/i );	}
	
	

#DEBUG OUTPUT
# save the command string to a local text file for debugging
open( FOUT , ">>./images.txt" ) || die "Cannot open: $!";
flock( FOUT , 2); 

print FOUT "\n";
foreach my $val ( @images ) { print FOUT "$val " } ;
print FOUT "\n";

flock( FOUT , 8);
close FOUT;


#  This directory is an NFS mount to the adproduction server.
chdir ("/usr/lib/cgi-bin/images/transfer/INTELLITUNE-IN/$BWorColor") or die "Could not chdir to image directory $!";

for my $i ( 0 .. $#images ) {
	my $imageext = ( $images[$i] =~ s/.*(\.\w{3,4})$/$1/r );   # grab the file extention
	my $imagename = ( $mactiveAdNumber . '_' . $customerName . '_' . $BWorColor . '_' . ($i + 1) . $imageext );  # create the file name
	system("/usr/bin/wget -q $images[$i] --output-document=$imagename");
}


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

exit;


# my $image_ = "$args[0]_ZenImage_" . $args[2] =~ s/https:\/\/acsmiclass\.zendesk\.com\/attachments\/token\/.*name=//r;
# https://acsmiclass.zendesk.com/attachments/token/vkbl14nwot8tsno/?name=lutheransocialservices_landingpage.jpg
