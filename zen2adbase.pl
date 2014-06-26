#!/usr/bin/perl -w
#
# Author: Luke Saunders
# Advance Central Services
# December 2013

use CGI;
use POSIX;
use strict;
umask 0000;

require "./zenxml-functions.pl"; 

# capture the called URL
my $cgin = CGI->new;
my $full_url = $cgin -> url ( -path_info=>1 ,  -query=>1 );

#URL MASK
# cut off the first part of the URL
$full_url =~ s|http://ppr.acsmi.com/cgi-bin/zen2adbase.pl\?ZEN2ADBASE=||i || die ;

my $clean_url = my_to_ascii ( $full_url );

# put the remaining arguments into an array after shaving/storing the ticket ID
$clean_url =~ s/(^\d{7,8})//; my $ticket_ID_ = $1; 
$clean_url = "$ticket_ID_$clean_url";

# _~_ is the Order Line Separator in the format string coming from Zendesk 
my @args = split( '_~_' , $clean_url );

my ( $sec , $min , $hour , $mday , $mon , $year ) = localtime();

# sec, min, hour, mday from localtime sometimes have single digits
my %hash1 = 	(
  '0' => "00",'1' => "01", '2' => "02",'3' => "03",'4' => "04",'5' => "05",'6' => "06",'7' => "07",'8' => "08",'9' => "09",);

# month from localtime starts with January = 0 
my %hash2 = 	(
  '0'  => "01",'1'  => "02",'2'  => "03",'3'  => "04",'4'  => "05",'5'  => "06",'6'  => "07",'7'  => "08",'8'  => "09",'9'  => "10",'10' => "11",'11' => "12",);
 
# year from localtime gives # of years since 1900.  
$year += 1900;	

$mon = $hash2 { $mon };
if ( $sec  < 10 && $sec  >= 0) { $sec  = $hash1{ $sec  }; }
if ( $min  < 10 && $min  >= 0) { $min  = $hash1{ $min  }; }
if ( $hour < 10 && $hour >= 0) { $hour = $hash1{ $hour }; }
if ( $mday < 10 && $mday  > 0) { $mday = $hash1{ $mday }; }

my $time1 = "$year$mon$mday$hour$min$sec";

# Write the entire  array of Order lines to a file for pickup.
open( FOUT , ">./adbase/in/zen2adbase-$ticket_ID_-$time1.txt" ) || die "Cannot open: ./adbase/in/zen2adbase-$ticket_ID_-$time1.txt $!";
flock( FOUT , 2); 

print FOUT "\n";
foreach my $val ( @args ) { print FOUT "$val \n" } ;
print FOUT "\n";

flock( FOUT , 8);
close FOUT;

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

system ( "./zen2adbase-XML-generator.pl"  ); 

exit;