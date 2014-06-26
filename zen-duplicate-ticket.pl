#!/usr/bin/perl -w
#
# Author: Luke Saunders
# Company: Advance Central Services
# January 2014


use POSIX;
use CGI;
use strict;

# capture the called URL
my $cgin = CGI->new;
my $full_url = $cgin -> url ( -path_info=>1 ,  -query=>1 );

# cut off the first part of the URL
$full_url =~ s|http://ppr.acsmi.com/cgi-bin/zen-duplicate-ticket.pl\?ZENDUP=||i || die ;

#$full_url =~ s|(%0A)||g;
$full_url =~ s|(%20)| |g;
$full_url =~ s|(%3A)|:|g;
$full_url =~ s|(%2F)|/|g;
$full_url =~ s|(%3D)|=|g;
$full_url =~ s|(%3F)|?|g;
$full_url =~ s|(%28)|(|g;
$full_url =~ s|(%29)|)|g;
$full_url =~ s|(%2C)|,|g;
$full_url =~ s|(%2B)|+|g;
$full_url =~ s|(%21)|!|g;
$full_url =~ s|(%27)|'|g;
$full_url =~ s|(%40)|@|g;

my @args = split( '~' , $full_url );
my $ticket_url_ = shift @args;
my $subject_ = shift @args;
my $ticket_id_ = shift @args;
my $assignee_ = shift @args;
#my $organization_ = shift @args;
my $group_ = shift @args;
my $requester_ = shift @args;

# Build the new ticket JSON..  

my $zen_ticket_json = "{\"ticket\":{\"subject\":\"$subject_ Copy\","
	. "\"comment\":{\"body\":\"Copy of ticket: $ticket_id_\\n\\nLink: $ticket_url_\\n\\n\"},"
	. "\"assignee_id\":$assignee_,"
	. "\"group_id\":$group_,"
	. "\"requester_id\":$requester_,"
	. "\"submitter_id\":$requester_,"
	. "\"custom_fields\":[";
	
for my $customfields_ ( @args ) { 
	my @customfield = split ( ':', $customfields_ );
	if ( $customfield[1] ) { $zen_ticket_json .= "{\"id\":$customfield[0],\"value\":\"$customfield[1]\"},"; }
}

$zen_ticket_json =~ s/,$/]}}/;

my $run_dir_ = "/usr/lib/cgi-bin/";
my $tmp_dir_ = "/usr/lib/cgi-bin/tmp/";
my $tmp_file_ = "$tmp_dir_$ticket_id_";

chdir ( $run_dir_ );

open ( fOUT, ">$tmp_file_" ) || die "Cannot open $tmp_file_ to create tmp json file $!\n";
print fOUT $zen_ticket_json;
close fOUT;

my $zen_API_URL_ = "https://acsmiclass.zendesk.com/api/v2/tickets.json";
my $zen_auth_ = 'lsaunder@acsmi.com/token:FdUcwJBqHkMf6JnVT5imQv9GF087uHbPy8ZwuDzd';
my $curlstring = "/usr/bin/curl --header 'Content-Type: application/json' --request POST --user $zen_auth_ --data \@$tmp_file_ $zen_API_URL_";

system ( $curlstring );

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