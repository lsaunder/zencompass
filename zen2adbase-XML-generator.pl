#!/usr/bin/perl -w
#
# Luke Saunders
# November 2013
# Advance Central Services
#
# A basic template for the Adbase XML importer
#   to input ads from zendesk to Mactive

use warnings; 
use strict;
use File::Copy 'move';
umask 0002;

require "./zenxml-functions.pl";  

####  Basic XML object declaration  ####

my $RUNDATES_ = {
	date	=>	'',									#
};

my $ADCONTENT_ = {
#	type_isattrb_	=>	'text',						#
	content			=>	'',							#
};

my $ADLOCINFO_ = {
	publication				=>	'',					#
	publication_2placement	=>	'',					#
	publication_2position	=>	'',					#
	rundates				=>	$RUNDATES_,			#	
};

my $AD_ = {
	buyer_2ad_2id			=>	'',					# Zendesk Ticket #
	ad_2content_hasattrb_	=>	$ADCONTENT_,		#
	ad_2type				=>	'',					#
#	ad_2width				=>	'',					#
#	ad_2height				=>	'',					#
#	ad_2unit_2of_2measure	=>	'inches',			# ? needed for both width and height ? always inches ?
	AdLocInfo				=>	$ADLOCINFO_,		#
#	ad_2slug				=>	'',					#
#	color					=>	'',					#
};

#my $ADDRESS_ 	= {
#	Addr1			=>	'',							#
#	City			=>	'',							#
#	State			=>	'',							#
#	Postal_2Code	=>	'',							#
#	Country			=>	'',							#
#};

my $CUSTOMER_	= {
	account_2number	=>	'',									#	
	Name1			=>	'',									#
	Name2			=>	'',									#
#	Address			=>	$ADDRESS_,							#
	Phone			=>	'',									#
	Email			=>	'',									#
};

#my $MATERIAL_ = {
	#MaterialName	=>	'',							#
	#Count			=>	0,							#
#};

#my $MATERIALS_ = {
#	Material	=>	$MATERIAL_,						#
#};

my $ORDERCUSTOMER_ = {
	Customer			=>	$CUSTOMER_,				#
	IsPrimaryOrderer	=>	'',						# 'true' to specify which customer is the orderer
	IsPrimaryPayor		=>	'',						# 'true' to specify which customer is the payor
};

my $ORDERCUSTOMERS_ = {
	OrderCustomer		=>	$ORDERCUSTOMER_,		#
};

my $ADBASEINFO_ = {
	OrderCustomers		=>	$ORDERCUSTOMERS_,		#
	pagination_2code	=>	'',						#
	notes				=>	'',						#
	Ad					=>	$AD_,					#
	#order_2source		=>	'ZenAds',				#
	#ad_2ordered_2by		=>	'zenads',			#
	ad_2sold_2by		=>	'zenads',				#
#	Materials			=>	$MATERIALS_,			#
};

my $ADBASEDATA_ = {
	AdBaseInfo	=>	$ADBASEINFO_,					#	
};

my $ADBASEXML_ = {
	AdBaseData	=>	$ADBASEDATA_,					#
};

####  End of basic XML object declarations  #####

####  Start of main script

my $fIMPORT;
my $fEXPORT;
my $run_dir_ = "/usr/lib/cgi-bin/";
my $pickup_dir_ = "./adbase/in/";
my $dropoff_dir_ = "./adbase/out/";
my $done_dir_ = "./adbase/done/";
my $pickup_file_ = "zen2adbase";
my $separate_orders_ = 0;
#my $mactive_customer_id_ = '';
#my $zen_customer_id_ = '';
#my $last_name_plus_phone_ = '';
my $xml_header_ = '<?xml version="1.0" encoding="UTF-8"?>';

chdir ( $run_dir_ );
my @zen_order_files = <$pickup_dir_$pickup_file_*.txt> ;

if ( scalar @zen_order_files > 0 )	{	
	my @zen_order = ();
	my $order_file = pop @zen_order_files;

	open ( $fIMPORT, "<", $order_file ) or die "Could not open input file: $order_file for reading! $!";
	while ( <$fIMPORT> ) { push ( @zen_order, $_ );  }
	close $fIMPORT;

	# Calculate the Run Dates
	# Requires the order of 4 fields coming from Zendesk
	# rundate1 before rundate2 before rundate filter before publication	
	
		#open ( FOUT, ">>./dates.txt");
		#for my $line_ ( 0 .. $#zen_order ) { print FOUT "$line_: $zen_order[$line_]";}
	
		my $orderIndex = 0;	my $orderSize = scalar @zen_order;
	while ($orderIndex < $orderSize){
		my $order_line_ = $zen_order[$orderIndex];
		#print FOUT "$orderIndex of $#zen_order: Processing $order_line_";

		if ( $order_line_ =~ m/date_filter:/ and ! ( $order_line_ =~ m/(Just these two days|-)/ ) ) {
			my @dates = ();
			my $date1 = ( $zen_order[$orderIndex-2] ) =~ s/(^.*_is_|\/|\s$)//gr;
			my $date2 = ( $zen_order[$orderIndex-1] ) =~ s/(^.*_is_|\/|\s$)//gr;
			my $date_builder_filter = ( $zen_order[$orderIndex] ) =~ s/(date_filter:|\s$)//gr;
			my $publication = $zen_order[$orderIndex+1] =~ s/(^.*_is_|\s$)//gr;			
			if ( $date_builder_filter =~ m/Home Delivery Days/ ) { 
				$date_builder_filter = $publication; }
			my $ad_ = ( $zen_order[$orderIndex+1] ) =~ s/_has_.*$//gr;
			build_run_dates ( $date1, $date2, \@dates, $date_builder_filter  );
			for my $date ( @dates ){ 
				push ( @zen_order, ("$ad_" . "_has_AdLocInfo_has_rundates_has_date_is_$date") ); }
			splice ( @zen_order, ($orderIndex - 2), 3 );
			$orderIndex = ($orderIndex - 3) ; $orderSize = ( $orderSize - 3 ); }
	
		elsif ( $order_line_ =~ m/date_filter:/ and
				( $order_line_ =~ m/(Just these two days|-)/ ) ){ 
					$zen_order[$orderIndex-2] =~ s/\///g; $zen_order[$orderIndex-1] =~ s/\///g; }
		elsif ( $order_line_ =~ m/OrderCustomers_1_has_OrderCustomer_has_Customer_has_account_2number/ ) { 
			$zen_order[$orderIndex] =~ s/(_is_.*)$//;
			my $orderPayer = $1;
			$orderPayer =~ s/^_is_.*(%23|#)|(%22|") .*\@.*$//g; 
			$zen_order[$orderIndex] .= "_is_$orderPayer";  }
		elsif ( $order_line_ =~ m/SEPARATEORDERS/ ) { $separate_orders_ = 1; }	
						
	
		$orderIndex++;	}
	
	#open ( FOUT, ">>./dates.txt");
	#print FOUT "\n\nOrder:\n";
	#for my $line_ ( @zen_order ) { print FOUT "$line_\n";}
	#close FOUT;

	ad_riders ( \@zen_order );
	
	# Fill the XML with @zen_order
	for my $order_line_ ( @zen_order ){
		if ( $order_line_ =~ m/_is_/ ) {

			$order_line_ =~ s/( \n|\n)//g;
			my $value_ = ( $order_line_ =~ s/(^.*_is_)//r ) ;
			$value_ ? my @xml_nodes_ = split ( '_has_', ($order_line_ =~ s/(_is_.*$)//r) ) : next;
					#print STDERR "fill_xml with: $order_line_\n";
			fill_xml ( $ADBASEXML_->{ 'AdBaseData' }->{ 'AdBaseInfo' }, \@xml_nodes_, $value_ ) ;	}	}

	
	# Here I may want to save the input to filesystem based on mactive_customer_id+zen_account_id and phone+lastname+zen_account_id
	
	my $output_file_ = ( $order_file =~ s/$pickup_dir_/$dropoff_dir_/r ) ;
	if ( $separate_orders_ ) { $output_file_ =~ s/.txt/.separate/; }
	else  { $output_file_ =~ s/.txt/.xml/ ; }
	open ( $fEXPORT, ">", $output_file_ ) or die "Could not open output file: $output_file_ for writing! $!";
	print $fEXPORT "$xml_header_\n" ;
	write_xml ( $ADBASEXML_, $fEXPORT );
	close $fEXPORT;

	indent_xml ( $output_file_ ) ;

	my $done_file_ = ( $order_file =~ s/$pickup_dir_/$done_dir_/r ) ;
	if ( ! ( move $order_file, $done_file_ ) ) { 
		die "Failed to rename $order_file to $done_file_ $!\n" ; 
	}
	
	if ( $separate_orders_ ) { separate_xml_orders( $output_file_ ) ; }
	#unlink ( $order_file ) or die "$0: Could not delete Order file $order_file $!";
}
else { die "No $pickup_file_ files to process in $pickup_dir_ \n"; }

exit;

####  End of main script

# 			print STDERR "fill_xml with .. $xml_nodes_[0] -> $value_\n";
#			print STDERR $order_line_ . "\n";

	# shift @zen_order; shift @zen_order;
	# =~ s/(^.*:|\s$)//gr

	# 	print STDERR "build_run_dates: $date1 | $date2 | $date_builder_filter";
