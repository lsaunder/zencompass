#!/usr/bin/perl -w
#
# Author: Luke Saunders
# Advance Central Services
# June 2014


use strict;
use File::Copy 'move';
use Text::Unidecode;
use MIME::Lite;

require "/usr/lib/cgi-bin/zenxml-functions.pl"; 

my $run_dir_ 	= '/usr/lib/cgi-bin/';
my $pickup_dir_	= './zen-cls-ocr/in/';
my $tmp_dir_ 	= './zen-cls-ocr/tmp/';
my $done_dir_ 	= './zen-cls-ocr/done/';
my $MAILHOST_	= 'mailrelay1.gr-press.net';
my $GHOSTSCRIPT	= '/usr/bin/gs';
my $TESSERACT   = '/usr/bin/tesseract';
my $WGET        = '/usr/bin/wget';
my $CURL 		= '/usr/bin/curl';
my $zen_auth_ 	= 'lsaunder@acsmi.com/token:FdUcwJBqHkMf6JnVT5imQv9GF087uHbPy8ZwuDzd';


my $LOGFILE = '/var/log/zenfaxOCR-responder.log';

open ( STDERR, ">>", $LOGFILE );
chdir ( $run_dir_ );

#  This script runs every 3 seconds for 1 minute.  It is intended to be put into cron as */1 * * * *
for my $i ( 0 .. 19 ) {
	
	system ("/bin/sleep 3");

	my @ocr_files = <$pickup_dir_*.txt>;
	
	for my $ocr_file ( @ocr_files ) {
			
		my $full_url = read_input_file ( $ocr_file );
		my $clean_url = my_to_ascii ( $full_url );
		my @args = split( '~', $clean_url );
		
		#
		# Example args string:
		# 55 12693820554-1216-173011-473.pdf https://acsmiclass.zendesk.com/attachments/token/dah4n5snua509bd/?name=12693820554-1216-173011-473.pdf
		#
		
		my $zen_ticket_ID_  	= $args[0];
		my $ocr_image_name_ 	= $args[1];
		my $ocr_image_url_  	= $args[2];
		my $reply_by_fax_   	= $args[$#args];
		my $ocr_pnm_name_   	= ( $ocr_image_name_ =~ s/pdf/pnm/r );
		my $ocr_text_basename_ 	= ( $ocr_image_name_ =~ s/\.pdf//r ) . "-tkt$zen_ticket_ID_";
		my $ocr_text_name_ 		= "$ocr_text_basename_.txt";
		my $GHOSTSCRIPTOPTS 	= "-sPAPERSIZE=a4 -sDEVICE=pnmraw -r300 -dNOPAUSE -dBATCH -dQUIET -sOutputFile=$ocr_pnm_name_ $ocr_image_name_";
		my $TESSERACTOPTS 		= "$ocr_pnm_name_ $ocr_text_basename_ -psm 1";
		my $WGETOPTS 			= "--output-document=$ocr_image_name_ --quiet  $ocr_image_url_";
		my $zen_ocr_file_ 		= "$done_dir_$ocr_text_name_";
		my $zen_url_ 			= "https://acsmiclass.zendesk.com/api/v2/tickets/$zen_ticket_ID_.json";
		my $CURLOPTS 			= "$zen_url_ --header \"Content-Type: application/json\" --request PUT --user $zen_auth_ --data \@$zen_ocr_file_";
		
		if ( $reply_by_fax_ eq "REPLY_BY_FAX_YES" ) { reply_by_fax ( $ocr_image_name_, $zen_ticket_ID_ ) };
		
		system("$WGET $WGETOPTS");
		
		unless ( -s $ocr_image_name_ ) { die "Downloading OCR image $ocr_image_name_ failed in zenfaxOCR.pl $!"; }
		if ( $ocr_image_name_ =~ m/(\.pdf$)/ ) {
			system("$GHOSTSCRIPT $GHOSTSCRIPTOPTS");
			if ( -s $ocr_pnm_name_ ) { system("$TESSERACT $TESSERACTOPTS"); }
			else { die "$ocr_pnm_name_ has size zero or does not exist.  Tesseract was not run. $!"; }
		}
		else { die "$ocr_image_name_ is not a PDF.  We can only use PDFs at this time. $!"; }
		move( $ocr_text_name_, $zen_ocr_file_ ) or die "Could not move $ocr_text_name_ to $zen_ocr_file_ $!";
		move( $ocr_file, $done_dir_ ) or die "Could not move $ocr_file to $done_dir_ $!";
		unlink($ocr_pnm_name_);
		unlink($ocr_image_name_);
		
		create_zen_JSON_file("$zen_ocr_file_");
		
		system("$CURL $CURLOPTS");
	}
}

exit 0;

# Send input file as only parameter
sub read_input_file { 
	die "$0: incorrect number of args $!" unless ( scalar @_  == 1 );
	die "$0: $_[0]: unreadable file $!" unless ( -r $_[0] );
	die "$0: $_[0]: 0 byte file received. $!" unless ( -s $_[0] );       												
	local @ARGV = ( $_[0] );   				
	my $input = do { local $/; <> }; 
	return $input;
}

sub reply_by_fax {
	my $zen_replyto_address_ = '';
	if ( $_[0] =~ m/^(\d{7,})/ ) { $zen_replyto_address_ = $1; }
	if ( $zen_replyto_address_ ) {
		$zen_replyto_address_ .= '@rcfax.com';
		print STDERR "Reply By Fax address: $zen_replyto_address_\n\n";

		my $message_ = MIME::Lite->new(
			From => 'support@acsmiclass.zendesk.com',
			To   => "$zen_replyto_address_",
			Type => 'multipart/related',
		);
		$message_->attach(
			Type => 'text/html',
			Data =>
			  "<html>" 
			  . "<body><br><br>"
			  . "<h2>MLive Media Group Classifieds</h2><br>"
			  . "<h3>Your fax submission has been received. Thank you!<br>"
			  . "Please reference ticket # $_[1] if you need to call for support.</h3><br>"
			  . "<table border='0'>"
			  . "<tr><td align='right'>Company -- </td> <td align='left'>MLive Media Group</td></tr>"
			  . "<tr><td align='right'>Address -- </td> <td align='left'>3102 Walker Ridge Dr NW</td></tr>"
			  . "<tr><td align='right'>City -- </td> <td align='left'>Walker</td></tr>"
			  . "<tr><td align='right'>State -- </td> <td align='left'>Michigan</td></tr>"
			  . "<tr><td align='right'>Zip/Postal Code -- </td> <td align='left'>49544</td></tr>"
			  . "<tr><td align='right'> -- </td><td align='left'></td></tr>"	
			  . "<tr><td align='right'>Classified -- </td> <td align='left'>1-800-878-1511</td></tr>"
			  . "<tr><td align='right'>Legals -- </td> <td align='left'>1-877-222-5423</td></tr>"
			  . "<tr><td align='right'>Obituaries -- </td> <td align='left'>1-877-253-4113</td></tr>"
			  . "<tr><td align='right'>Recruitment -- </td> <td align='left'>1-800-866-5529</td></tr>"
			  . "</table>"
			  . "</body>"
			  . "</html>",
			Disposition => 'attachment',
		);
	
		$message_->send( 'smtp', $MAILHOST_ );
		$message_->replace( "To" => 'lsaunder@acsmi.com' );
		$message_->send( 'smtp', $MAILHOST_ );
		
	}
	else { print STDERR `date`, ": No phone number found for reply by fax for $_ \n\n"; }
}

#
# Build the OCR text JSON..
#
# example $_[0]: 12693820554-1226-150538-424-tkt1000002.txt

#sub create_ocr_file {
#	unless ( -s $ocr_image_name_ ) { die "Downloading OCR image [ $ocr_image_name_ ] failed in zenfaxOCR.pl $!"; }
#	if ( $ocr_image_name_ =~ m/(\.pdf$)/ ) {
#		system("$GHOSTSCRIPT $GHOSTSCRIPTOPTS");
#		if ( -s $ocr_pnm_name_ ) { system("$TESSERACT $TESSERACTOPTS"); }
#		else { die "$ocr_pnm_name_ has size zero or does not exist.  Tesseract was not run. $!"; }
#	}
#	else { die "$ocr_image_name_ is not a PDF.  We can only use PDFs at this time. $!"; }
#	move( $ocr_text_name_, $zen_ocr_file_ ) or die "Could not move $ocr_text_name_ to $zen_ocr_file_ $!";
#	unlink($ocr_pnm_name_);
#	unlink($ocr_image_name_);
#}

sub create_zen_JSON_file {
	local $^I   = "";           												# set inline editing switch.
	local @ARGV = ( $_[0] );   												 	# input file.
	#my $zen_text_field_ = '21334845'; 		# send to comments instead			# custom zendesk field ID to store ocr text.
	my $ocr_text_ = do { local $/; <> };    									# read in the raw ocr text.
	$ocr_text_ = unidecode($ocr_text_);    										# turn unicode chars into ascii chars.
	$ocr_text_ =~ tr| a-zA-Z0-9"\/\n\r\.\(\)\-\:\,\{\}\;\'\*\@\#\!\%\&|_|c;		# replace unwanted/unknown/control chars with _ especially
																				## backslashes so that new lines and double quotes
																				## are the only escaped chars in $ocr_text_.
	$ocr_text_ =~ s/\"/\\\"/g;    												# escape any double quotes.
	$ocr_text_ =~ s/\n/\\n/g;     												# "\n" into '\n'.
	while ( $ocr_text_ =~ s/\\n\\n/\\n/g ) { (); }    							# remove multiple \n's.
	     																		# (below) construct the API-ready JSON for Zendesk.
	#print "{\"ticket\":{\"custom_fields\":[{\"id\":$zen_text_field_,\"value\":\"$ocr_text_\"}]}}";  # send to comments instead
	print "{\"ticket\":{\"comment\":{\"body\":\"Attempted Fax OCR Text:\\n\\n$ocr_text_\",\"public\":\"false\"}}}";
}
