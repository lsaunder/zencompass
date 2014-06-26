#!/usr/bin/perl -w

use strict;
use CGI;
use POSIX;

require "./zenxml-functions.pl"; 

# capture the called URL
my $cgin = CGI->new;
my $full_url = $cgin -> url ( -path_info=>1 ,  -query=>1 );

#URL MASK
# cut off the first part of the URL
$full_url =~ s|http://ppr.acsmi.com/cgi-bin/zen-cls-new-customer.pl\?ZEN_CLS_NEW_CUSTOMER=||i || die ;

my $clean_url = my_to_ascii ( $full_url );

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

open( FOUT , ">>/var/log/adbase2zen-new-users.log" ) || die "$0: Cannot open: $!";

#print FOUT "Full URL: $full_url\n";
my @args = split ('~', $clean_url);

chdir ("/usr/lib/cgi-bin/tmp") or die "$0: Could not chdir $!";

#save the command string to a local text file for debugging
foreach my $val_ ( @args ) { print FOUT "$val_\n"; }

my $zenTicketID = shift @args;
my $zenuserEmail = shift @args;
my $zenuserPhone = shift @args;
my $zenuserFirstName = shift @args;
my $zenuserName = shift @args;
my $zenuserExtID = shift @args;

unless ( $zenuserFirstName =~ m/^\s*$/ ) { $zenuserName = "$zenuserName, $zenuserFirstName" ;}
$zenuserName .= " #$zenuserExtID";

my $zenNewCustomerField = '21559604';
my $zenUpdateCustomerField = '21774630';

if ($zenuserEmail =~ m/^\s*$/) { $zenuserEmail = "$zenuserExtID\@no-mactive-email.com"; }

my $zen_json_object = "{\"user\":{\"name\":\"$zenuserName\",\"email\":\"$zenuserEmail\",\"verified\":true,\"external_id\":\"$zenuserExtID\",\"phone\":\"$zenuserPhone\"}}";
print FOUT "saving to tmp file..\n$zen_json_object\n";

open ( fTMP, '>', "./tmp1$zenTicketID" ) or die "$0: Could not open temp file for writing 1st $!";
binmode ( fTMP );
print fTMP $zen_json_object;
close fTMP;

my $zen_API_URL_ = "https://acsmiclass.zendesk.com/api/v2/users.json";
my $zen_auth_ = 'lsaunder@acsmi.com/token:FdUcwJBqHkMf6JnVT5imQv9GF087uHbPy8ZwuDzd';
my $curlstring = "/usr/bin/curl --header \"Content-Type: application/json\" --request POST --data \@tmp1$zenTicketID --user $zen_auth_  $zen_API_URL_";
	
my $newUserJSON = `$curlstring`;

my $zenuserID = $newUserJSON =~ s/(^.*"id":)//rg;
$zenuserID =~ s/,".*$//;

$zen_json_object =  "{\"ticket\":{\"requester_id\":$zenuserID,\"custom_fields\":[{\"id\":$zenNewCustomerField,\"value\":\"no\"},{\"id\":$zenUpdateCustomerField,\"value\":\"no\"}]}}";
print FOUT "saving to tmp file..\n$zen_json_object\n";

open ( fTMP, '>', "./tmp2$zenTicketID" ) or die "$0: Could not open temp file for writing 2nd $!";
binmode ( fTMP );
print fTMP $zen_json_object;
close fTMP;

$zen_API_URL_ = "https://acsmiclass.zendesk.com/api/v2/tickets/$zenTicketID.json";
$curlstring = "/usr/bin/curl --header \"Content-Type: application/json\" --request PUT --data \@tmp2$zenTicketID --user $zen_auth_  $zen_API_URL_";

my $updateTicketJSON = `$curlstring`;

#print FOUT "zenuserID = $zenuserID\n";

# "id":326735744,

#DEBUG OUTPUT

print FOUT "\n$newUserJSON\n\n$updateTicketJSON\n\n";
close FOUT;

#unlink ( $zenTicketID );

exit;

#curl -v -u {email_address}:{password} https://{subdomain}.zendesk.com/api/v2/users.json \
#  -H "Content-Type: application/json" -X POST -d '{"user": {"name": "Roger Wilco", "email": "roge@example.org"}}'



