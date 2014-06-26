#!/usr/bin/perl -w
#
# Luke Saunders
# January 2014
# Advance Central Services
#

use strict;
use POSIX;
use File::Copy 'move';

# Hash of the AdBase field names to the Zendesk custom field ID's
#	Using the convention of _2 in place of hyphen's (see zenxml-functions.pl)
my %zen2adbase = (
	#Name1					=>	21359975,
	#Name2					=>	21619814,
	account_2number			=>	21315639,
#	Addr1					=>	21484590,
#	City					=> 	21326144,
#	State					=>	21326154,
#	Postal_2Code			=>	21326164,
	#Phone					=>	21359985,
	#Email					=>	21326874,
	#ad_2type				=>	21484610,
	#ad_2width				=>	21315149,
	#ad_2height				=>	21315159,
	#publication				=>	21326184,
	#publication_2placement	=>	21484630,
	#publication_2position	=>	21484640,
	#color					=>	21484620,
	#MaterialName			=>	21359995,
	#Count					=>	21326854,
	ad_2number				=>	21445745,
	price					=>	21438135,
	non_2pub_2notes			=>	21773410,
);

# The dropdown fields need to use the tag value and not the option value to be updated
#	so we need to keep track of which fields are dropdowns. using a hash so we can use exists function
my %zen_dropdowns = ( 
#	21326134 => 'Customer Type',
#	21314529 => '',
	21484600 => 'Sales Rep',
	21484610 => 'ad-type',
	21484620 => 'color',
	21326184 => 'publication',
	21484630 => 'publication-placement',
	21484640 => 'publication-position',
	21359995 => 'MaterialName',
);

my $zenNewCustField = '21774630';
my $adbaseNewCustText = 'Customer status="new"';

my $run_dir_ = "/usr/lib/cgi-bin/";
my $tmp_dir_ = "./tmp/";
my $done_dir_ = "./adbase/response/processed/";

my $LOGFILE = "/var/log/adbase2zen-responder.log";

open ( fLOG, ">>", $LOGFILE ) or die "$0: Could not open $LOGFILE for writing. $!";

chdir ( $run_dir_ );

# Build the new ticket JSON..  

#  This script runs every 5 seconds for 1 minute.  It is intended to be put into cron as */1 * * * *
for my $i ( 0 .. 12 ) {
	
	system ("/bin/sleep 5");

	my @response_files = <./adbase/response/zen2adbase-*_resp.xml>;
	
	for my $response_file ( @response_files ) {
		open ( fIN, "<",  $response_file ) or die "$0: Could not open $response_file for reading. $!\n";
	
		my $booking_error_ = 0;
		my $new_customer_ = 0;
		my $zen_ticket_json =  "{\"id\":$zen2adbase{'non_2pub_2notes'},\"value\":\"\"},";  # clear out mactive error field before building
		
		# 
		# var updateNewCust 			=	[ 'label:contains(Update New Customer)' , '#ticket_fields_21774630' ];
		while ( <fIN> ) { 
			my $line_ = $_ =~ s/(^\s*)//r;							# remove leading whitespace
			if ( $line_ =~ m/$adbaseNewCustText/) {					# check for new customer 
					$new_customer_ = 1; }
			if	( scalar ( () = $line_ =~ m/(<|>)/g ) == 4 ) {  	# looking to find lines in the xml file with 4 lt/gt braces
				$line_ =~ s/(^<|>$)//g;								# remove leading and trailing lt/gt brackets
				$line_ =~ s/(<\/.*)//g; 							# remove entire closing xml bracket  ( </account-number )
				$line_ =~ s/ \w*="\w*">/>/; 						# remove any remaining attribute text ( type="" )
				$line_ =~ s/\s$//g;									# remove trailing new line
				my $adbase_field = $line_ =~ s/>.*//r;
				$adbase_field =~ s/-/_2/g;							# make _2 for hyphen substitution to match zen2adbase hash
				if ( $adbase_field =~ m/non_2pub_2notes/ ) { 		# check for booking error
					$booking_error_ = 1; }	
				my $value_ = $line_ =~ s/.*>//r;
				$value_ =~ s/&apos;/'/g;							# response file uses a &apos; for apostrophe chars, replace 
				$value_ =~ s/&lt;/</g;
				$value_ =~ s/&gt;/>/g;
				if ( exists $zen2adbase{$adbase_field} and $value_ ) {
					if ( exists $zen_dropdowns{$zen2adbase{$adbase_field}} ) {  # check if this field is a zen dropdown
						$value_ = lc $value_;							# lower case value for dropdown tag
						$value_ =~ s/ |-|\+|,/_/g;						# replace spaces,hyphens,plus signs,commas with underscores to mimic dropdown tag
					}
					#print $adbase_field . ' ' . $value_ . "\n";	
					$zen_ticket_json .= "{\"id\":$zen2adbase{$adbase_field},\"value\":\"$value_\"},";
				}
			}
		}
	
		$zen_ticket_json =~ s/,$/]}}/;
		
		if ( $new_customer_ ) {
			$zen_ticket_json = "\"custom_fields\":[{\"id\":$zenNewCustField,\"value\":\"true\"}," . $zen_ticket_json; }
		else { $zen_ticket_json = "\"custom_fields\":[" . $zen_ticket_json; }	
		
		if ( $booking_error_ ) { $zen_ticket_json =  "{\"ticket\":{\"status\":\"open\"," . $zen_ticket_json; }
		else { $zen_ticket_json =  "{\"ticket\":{\"status\":\"hold\"," . $zen_ticket_json; }
		# 
	
		my $ticket_id_ = $response_file =~ s/(\.\/adbase\/response\/zen2adbase-|-\d*_resp\.xml)//gr;
		my $tmp_file_ = "$tmp_dir_$ticket_id_.tmp";
		
		print fLOG "\n\nWriting Zendesk response JSON to $tmp_file_:\n$zen_ticket_json\n\n";
	
		open ( fOUT, ">", $tmp_file_ ) || die "$0: Cannot open $tmp_file_ to create tmp json file $!\n";
		print fOUT $zen_ticket_json;
		close fOUT;
		
		my $zen_API_URL_ = "https://acsmiclass.zendesk.com/api/v2/tickets/$ticket_id_.json";
		my $zen_auth_ = 'lsaunder@acsmi.com/token:FdUcwJBqHkMf6JnVT5imQv9GF087uHbPy8ZwuDzd';
		my $curlstring = "/usr/bin/curl --header 'Content-Type: application/json' --request PUT --user $zen_auth_ --data \@$tmp_file_ $zen_API_URL_";
		
		system ( $curlstring );
		
		#unlink $response_file or die "$0: Could not delete response file: $response_file $!\n";
		move ( $response_file, $done_dir_ ) or die "$0: Could not move response file: $response_file to $done_dir_ $!\n";
		unlink $tmp_file_ or die "$0: Could not delete tmp json file: $tmp_file_ $!\n";
	}

}


exit;

