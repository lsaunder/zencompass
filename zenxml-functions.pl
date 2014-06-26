#!/usr/bin/perl -w
#
# Luke Saunders
# January 2013
# Advance Central Services

# ## Before updates to ad_riders to combine the digital rider with the print

use strict;
use warnings;
use Date::Calc qw(:all);

### XML elements with subelements look LIKE_ THIS_ WITH_ ALL_ CAPS_ PLUS_ AN_ UNDERSCORE_ 
##
### If an XML element has one or more attributes: 
##  	<xml-element-name attribute-name1="attribute-value1">content-value</xml-element-name>
## 
##  1. it's a hash (even if it has no subelements) 
##		and it is named with an appended _has_attrb in its parent element
##
##  2. its attributes are each a subelement with _is_attrb appended to the name
##
##	3. the value of the XML element is populated as the value of a subelement called content
##
##		.. for example .. 
##
##  		my $ITEM_ = {
##	  			name_isattrb_	=>	'Luke Saunders',		
##	  			flavor_isattrb_	=>	'Habepino Jalapenero',
##	  			content => 'The answer is 42',			
##  		};
## 
##			my $ARTICLE_ = {
##				item_hasattrb_ => $ITEM_,
##			};
##
##			my $GROUP_ = {
##				article => $ARTICLE_ 
##			};
##
### The final output would be:
##
##		<article>
##			<item flavor="Habepino Jalapenero" name="Luke Saunders" >The answer is 42</item>
##		</article>
###
  
### XML elements with name conflicts
##
### If any element uses a name which is a reserved word or uses an unallowed character in perl:
##
##	1. if it uses a perl reserved word or is a duplicate named element, append _1 to the name
##
##	2. if it uses hyphens, use _2 instead of the hyphens
##
##		package_1       => '',		#  package is a perl reserved word
##		depth_1         => '',		#  depth is a perl reserved word
##		width_1         => '',		#  width is a perl reserved word
## 		width_1_1		=> '',		#  both _1's will be removed during output
##									   leaving 2 width elements
##
##		width_2units    => '',		#  width-units not allowed
##		depth_2units	=> '',		#  depth-units not allowed
###

####  Start of Function Definitions

# Usage: fill_xml ( $ADBASEXML_->{ 'AdBaseData' }->{ 'AdBaseInfo' }, \@xml_nodes_, $value_ );
# 	-places a value into a hash of hashes.  each child hash represents a child xml element.
#	-arg1 is the hash. arg2 is an array of the values' xml parent elements. arg3 is the value.
# If the hash key's value returns true (the element already exists): 
#	suffix _1 to the key. This will ensure the same named elements are grouped correctly.
#	..the _1's fall off in the write_xml function. 
sub fill_xml {	
	if ( ref $_[1] eq 'ARRAY' and (scalar @{$_[1]} > 1) and ref $_[2] eq '' ) { 
		fill_xml ( $_[0]->{ (shift @{$_[1]}) }, \@{$_[1]}, $_[2]  );  }	
	elsif ( ref $_[1] eq 'ARRAY' and (scalar @{$_[1]} == 1) and ref $_[2] eq '' ) { 
		my $key = @{ $_[1]}[0];  
		until ( ! $_[0]->{$key} ) { $key .= '_1' }  
		$_[0]->{$key} = $_[2];	}	
	else {	die "does not conform to fill_xml arg requirement \n ";	}	}


sub write_xml { 
	if ( ref( $_[0] ) eq 'HASH' and tell $_[1] != -1 ) {									# assert arg 1 is a hash and arg 2 is a valid filehandle
		for my $field_ ( keys %{ $_[0] } ) {												# interate through arg 1 hash by key name
			my $field_type_ = ref( $_[0]->{$field_} );										# store the type of field the hash key is pointing to
			my $field_name_ = ( $field_ =~ s/_1//rg ) ;										# remove all _1 (perl reserved word named elements and ad groups use these)
			$field_name_ = ( $field_name_ =~ s/_2/-/rg ) ;									# if the key name contains a _2 replace the printed name with a hyphen
			my $hasattrb_ = ( $field_name_ =~ s/_hasattrb_// );								# check if the xml field has an attribute
			
			if ( $field_type_ eq '' or $field_type_ eq 'SCALAR' ) {							# if field type is a literal or a pointer to a literal
				print { $_[1] } "<$field_name_>$_[0]->{ $field_ }</$field_name_>\n" ;	}	# write the field to the file
				
			elsif ( $field_type_ eq 'HASH' ) {												# if field type is a hash
				if ( $hasattrb_ ) { 
					print { $_[1] } "<$field_name_";
					for my $attrb_field_ ( keys %{ $_[0]->{$field_} } ) {
						if ( $attrb_field_ =~ m/_isattrb_/ ) { 
							print { $_[1] }  " " . ($attrb_field_ =~ s/_isattrb_//r) . "\=\"$_[0]->{$field_}->{$attrb_field_}\"" ; }}
					print { $_[1] } ">$_[0]->{$field_}->{'content'}</$field_name_>\n";}
				else{
					print { $_[1] } "<$field_name_>\n" ;							# print first xml element
					write_xml( $_[0]->{$field_}, $_[1] );							# call write_xml again on the hash and pass the same filehandle
					print { $_[1] } "</$field_name_>\n" ;	}	}	}	}	}		# print the 2nd xml element


sub indent_xml {
	local $^I = "";				# set inline editing switch
	local @ARGV = ( $_[0] );	# input file
	my $indent_ = '';
	while ( <> ){
		$_ =~ s/<ad-content>/<ad-content type="text">/;		
		if ( m/(^.*>-?<.*$)/ ) { next; }																				# do not output empty elements
		elsif ( m/(^<(\w|-| |=|")*>$)/ ) {				print "$indent_$_"; $indent_ = $indent_ . "  "; }  				# add 2 spaces to indent
		elsif ( m/(^<\/(\w|-)*>$)/ ) { 					$indent_ = substr ( $indent_, 0, -2 ); print "$indent_$_"; }	# shorten indent by 2
		elsif ( m/(^<(\w|-| |=|")*>.*<\/(\w|-)*>$)/ ) { print "$indent_$_"; }  											# leave indent untouched
		elsif ( m/xml version/ ) { 						print $_ ; }													# leave header record unchanged
		else { 											die "$_ does not conform to expected XML formatting: $!"; }	}	}

### Function separate_xml_orders
## Takes one argument. a filepath to an adbase xml import file with a .separate extention
##   creates a separate xml file for each ad in the order and deletes the original
 		
sub separate_xml_orders {
	
	my $order_file_ = shift or die "$0: separate_xml_orders did not receive an argument $!";
	unless ( $order_file_ =~ m/\.separate$/ ) 
		{ die "$0: separate_xml_orders received file: $order_file_ which has the wrong extention $!"; }
		
	( $order_file_ =~ m/zen2adbase-(\d{7})-/ ) ? my $zenID = $1 : die "$0: separate_xml_orders could not find the Zen ID $!";		
	
	my @order_ = ();	
	open ( fIN, '<', $order_file_ );	
	
	while ( <fIN> ) { push ( @order_, $_ ) ; }
	close fIN;

	my @startAdIndexes = ();  
	my @endAdIndexes = ();
	# build an array of the starting and ending indexes for
	# all ad entries.
	for my $index_ ( 0 .. $#order_ ) {
		if ( $order_[$index_] =~ m/^\s*<Ad>\s*$/ ) { push ( @startAdIndexes, $index_ ); }
		elsif ($order_[$index_] =~ m/^\s*<\/Ad>\s*$/ ) { push ( @endAdIndexes, $index_); }	
		else { next; }
	}	

	unless ( $#startAdIndexes == $#endAdIndexes ) 
		{ die "$0: separate_xml_orders found unmatched number of Ad tags in file: $order_file_ $!" ; }
		
	for my $ad_index_ ( 0 .. $#startAdIndexes ) {
		open ( fOUT, '>', ( $order_file_ . $ad_index_ ) );  #open new file with index appended.
		for my $order_index_ ( 0 .. $#order_ ) {
			my $printline = 1;
			for my $check_index_ ( 0 .. $#startAdIndexes ) {
				next if ( $check_index_ == $ad_index_ );
				$printline = 0 if ( $order_index_ >= $startAdIndexes[$check_index_] and 
					$order_index_ <= $endAdIndexes[$check_index_] );
			}
			print fOUT $order_[$order_index_] if $printline;
		}
		close fOUT;	
	}	

}	


# Michigan publications have varying home delivery schedules
my $flint_journal = 			{ 1=>0, 2=>1, 3=>0, 4=>1, 5=>1, 6=>0, 7=>1 };
my $saginaw_news = 				{ 1=>0, 2=>1, 3=>0, 4=>1, 5=>1, 6=>0, 7=>1 };
my $bay_city_times = 			{ 1=>0, 2=>1, 3=>0, 4=>1, 5=>1, 6=>0, 7=>1 };
my $grand_rapids_press = 		{ 1=>0, 2=>1, 3=>0, 4=>1, 5=>0, 6=>0, 7=>1 };
my $kalamazoo_gazette = 		{ 1=>0, 2=>1, 3=>0, 4=>1, 5=>0, 6=>0, 7=>1 };
my $muskegon_chronicle = 		{ 1=>0, 2=>1, 3=>0, 4=>1, 5=>0, 6=>0, 7=>1 };
my $jackson_citizen_patriot = 	{ 1=>0, 2=>1, 3=>0, 4=>1, 5=>0, 6=>0, 7=>1 };
my $ann_arbor_news = 			{ 1=>0, 2=>0, 3=>0, 4=>1, 5=>0, 6=>0, 7=>1 };
my $thursdays_and_sundays = 	{ 1=>0, 2=>0, 3=>0, 4=>1, 5=>0, 6=>0, 7=>1 };
my $sundays_only = 				{ 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>1 };
my $all_days = 					{ 1=>1, 2=>1, 3=>1, 4=>1, 5=>1, 6=>1, 7=>1 };

my %delivery_days = (
	'Flint Journal'				=>	$flint_journal,
	'Saginaw News'				=>	$saginaw_news,
	'Bay City Times'			=>	$bay_city_times,
	'Grand Rapids Press'		=>	$grand_rapids_press,
	'Kalamazoo Gazette'			=>	$kalamazoo_gazette,
	'Muskegon Chronicle'		=>	$muskegon_chronicle,
	'Jackson Citizen Patr'		=> 	$jackson_citizen_patriot,
	'Ann Arbor News'			=>	$ann_arbor_news,
	'Sundays Only'				=>	$sundays_only,
	'Thursdays and Sundays'		=>	$thursdays_and_sundays,
	'All Days'					=>	$all_days,	);

# outputted dates need to have a two digit day and month
my %datehash = 	(
		'00' => "00", '01' => "01", '02' => "02", '03' => "03", '04' => "04",
		'05' => "05", '06' => "06", '07' => "07", '08' => "08", '09' => "09",
		 '0' => "00",  '1' => "01",  '2' => "02",  '3' => "03",  '4' => "04",
		 '5' => "05",  '6' => "06",  '7' => "07",  '8' => "08",  '9' => "09", 
		'10' => "10", '11' => "11", '12' => "12", '13' => "13", '14' => "14",
		'15' => "15", '16' => "16", '17' => "17", '18' => "18", '19' => "19",		
		'20' => "20", '21' => "21", '22' => "22", '23' => "23", '24' => "24",
		'25' => "25", '26' => "26", '27' => "27", '28' => "28", '29' => "29",
		'30' => "30", '31' => "31",		);

# Usage example: build_run_dates ( "12182014", "01182015", \@dates, "Kalamazoo Gazette");
sub build_run_dates { 
	if ( $_[0] =~ m/\d{8}/ and $_[1] =~ m/\d{8}/ and ref($_[2]) eq 'ARRAY' and exists $delivery_days{$_[3]} ){		
		my $date1_year = $_[0] =~ s/^\d{4}//r;
		my $date1_mon = $_[0] =~ s/\d{6}$//r;
		my $date1_mday = $_[0] =~ s/(^\d{2}|\d{4}$)//rg;
		my $date2_year = $_[1] =~ s/^\d{4}//r;
		my $date2_mon = $_[1] =~ s/\d{6}$//r;
		my $date2_mday = $_[1] =~ s/(^\d{2}|\d{4}$)//rg;
		until ( Day_of_Year($date1_year, $date1_mon, $date1_mday) > Day_of_Year ($date2_year, $date2_mon, $date2_mday) and $date1_year eq $date2_year ) {
			my $date_ = ( $datehash{$date1_mon} ) . ( $datehash{$date1_mday} ) . $date1_year;
				if ( $delivery_days{$_[3]}->{Day_of_Week( $date1_year, $date1_mon, $date1_mday )} ) { 
					push ( @{$_[2]}, "$date_"); }
			( $date1_year, $date1_mon, $date1_mday ) = Add_Delta_Days( $date1_year, $date1_mon, $date1_mday, 1 );	}	}
	else { die "build_run_dates died with unexpected args: $_[0] | $_[1] | $_[3]  $!\n"; }	}
	
sub build_digital_run_dates {
	if ( $_[0] =~ m/\d{8}/ and $_[1] =~ m/1|7/ and ref($_[2]) eq 'ARRAY' ){		
		my $year = $_[0] =~ s/^\d{4}//r;
		my $mon = $_[0] =~ s/\d{6}$//r;
		my $day = $_[0] =~ s/(^\d{2}|\d{4}$)//rg;
		my $count = 0 + $_[1];
		until ( $count <= 0 ) { 
			my $date_ = ( $datehash{$mon} ) . ( $datehash{$day} ) . $year;
			push ( @{$_[2]}, $date_ );  
			( $year, $mon, $day ) = Add_Delta_Days( $year, $mon, $day, 1 );
			$count--;
		} 
	}
	else { die "build_digital_run_dates died with unexpected args: $_[0] | $_[1] $!\n"; }	
}

# Some print ads always need a digital ad attached.
my %riderhash = (
	'positionhash'	=>	{
		'Obituaries'			=> 	[
			#'_has_ad_2type_is_CLS Obits',  # Not needed - combined on single ad with the print which already has the type
			'_has_AdLocInfo_1_has_publication_is_MMG_Other',
			'_has_AdLocInfo_1_has_publication_2placement_is_Digital Class Obits',
			'_has_AdLocInfo_1_has_publication_2position_is_1yr Guest Book',	],
		'In Memoriams'	=> 	[
			#'_has_ad_2type_is_CLS Obits',
			'_has_AdLocInfo_1_has_publication_is_MMG_Other Premium',
			'_has_AdLocInfo_1_has_publication_2placement_is_Obits',
			'_has_AdLocInfo_1_has_publication_2position_is_In Memoriams',	],	},	);
			
sub ad_riders {
	if ( ref $_[0] eq 'ARRAY' ) {
		my $order_line_count_ = scalar @{$_[0]}; my $i_ = 0;
		until ( $i_ >= $order_line_count_ ) {
			if ( @{$_[0]}[$i_] =~ m/publication_2position_is_/ ) {
				my ( $schedule_, $startday_) = @{$_[0]}[$i_] =~ m/_digitalschedule:(digital_\d)_*startday:(\d\d\/\d\d\/\d\d\d\d)/ ;
				( defined ($schedule_) ) ? ( $schedule_ =~ s/(^digital_)|(_*$)//g ) : ( $schedule_ = '' ) ;
				( defined ($startday_) ) ? ( $startday_ =~ s/\///g ) : ( $startday_ = '' ) ;
				@{$_[0]}[$i_] =~ s/_digitalschedule:.*$//;  # cut off attached digital schedule format string from the position string
				my $positionString = @{$_[0]}[$i_];
				if ( $schedule_ =~ m/^1|7$/ and $startday_ =~ m/\d{8}/ ){
					for my $position_ ( keys $riderhash{'positionhash'} ) {					
						if ( $positionString =~ m/position_is_$position_/ ) {
							my $ad_ = $positionString =~ s/_has_.*$//gr;
							#my $ad_num = ((( $ad_ =~ tr/_// ) + 1) / 2 );
							for my $rider_ ( @{$riderhash{'positionhash'}{$position_}} ){ 
								push ( @{$_[0]}, "$ad_$rider_"  );  }
 								#push ( @{$_[0]}, ("$ad_" . "_has_buyer_2ad_2id_is_$_[0][1]digital$ad_num") );
								my @dates_ = ();
								build_digital_run_dates ( $startday_, $schedule_, \@dates_ ); 
								for my $date_ ( @dates_ ) {  push @{$_[0]}, ("$ad_" . "_has_AdLocInfo_1_has_rundates_has_date_is_$date_" ) ;  }	 
						last;	}	}	}					
				}	$i_++; }	} 
	else { die "Does not conform to ad_riders arg requirements"; }	}



# Replaces ascii/unicode characters that were converted into HTML hex codes back into ascii
sub my_to_ascii {
	my $string = shift or die "$0: my_to_ascii did not receive an argument $!";

	# unicode to ascii
	$string =~ s|(%E2%80%8[1-9a-fA-F])| |g;
	$string =~ s|(%E2%80%9[1-5])|-|g;
	$string =~ s|(%E2%80%96)|\||g;
	$string =~ s|(%E2%80%97)|_|g;
	$string =~ s|(%E2%80%9[8-9a-bA-B])|'|g;
	$string =~ s|(%E2%80%9[c-fC-F])|"|g;
	$string =~ s/%E2%80%B(2|5)/'/g;
	$string =~ s/%E2%80%B(3|4|6|7)/"/g;
	$string =~ s/%E2%80%A2/&#8226;/g;  # bullet
	
	# html to ascii
	$string =~ s|(%09)|&#xA;|g;  # line break
	$string =~ s|(%0A)||g;
	$string =~ s|(%0D)||g;
	$string =~ s|(%20)| |g;
	$string =~ s|(%21)|!|g;
	$string =~ s|(%22)|"|g;
	$string =~ s|(%23)|#|g;
	$string =~ s|(%24)|\$|g;
	$string =~ s|(%25)|%|g;
	$string =~ s|(%26)|&amp;|g;  # ampersand &
	$string =~ s|(%27)|'|g;
	$string =~ s|(%28)|(|g;
	$string =~ s|(%29)|)|g;
	$string =~ s|(%2A)|*|g;
	$string =~ s|(%2B)|+|g;
	$string =~ s|(%2C)|,|g;
	$string =~ s|(%2D)|-|g;
	$string =~ s|(%2E)|.|g;
	$string =~ s|(%2F)|/|g;
	$string =~ s|(%3A)|:|g;
	$string =~ s|(%3B)|;|g;
	$string =~ s|(%3C)|&lt;|g;  # less than bracket <
	$string =~ s|(%3D)|=|g;
	$string =~ s|(%3E)|&gt;|g;  # greater than bracket >
	$string =~ s|(%3F)|?|g;
	$string =~ s|(%40)|@|g;
	$string =~ s|(%5B)|[|g;
	$string =~ s|(%5C)|\\|g;
	$string =~ s|(%5D)|]|g;
	$string =~ s|(%5E)|^|g;
	$string =~ s|(%5F)|_|g;
	$string =~ s|(%60)|`|g;
	$string =~ s|(%7B)|{|g;
	$string =~ s|(%7C)|\||g;
	$string =~ s|(%7D)|}|g;
	$string =~ s|(%7E)|~|g;
	
	return $string;
}


# Makes an API call to Zendesk to get the ID of a user based on their email address
#	Return 0 if the user doesn't exist.
#	Takes 1 parameter, the users email.
# i.e.  my $userid = zenEndUserIdByEmail ( 'johndoe@gmail.com' );
sub zenEndUserIdByEmail {
	my $user_email = shift or die "$0: no email parameter sent to zenEndUserExist() $!";

	my $auth_ = '\'lsaunder@acsmi.com/token:FdUcwJBqHkMf6JnVT5imQv9GF087uHbPy8ZwuDzd\'';
	my $query_ = "'https://acsmiclass.zendesk.com/api/v2/search.json?query=email:$user_email'";

	my $curlstring = "/usr/bin/curl --header 'Content-Type: application/json' --request GET --user $auth_ $query_";

	my $response = ` $curlstring `;
	
	my $id = 0;
	if ( $response =~ m/"id":(\d*),/ ) { $id = $1; }
	
	return $id;
}


# Parameters: Name, Email, Phone, Mactive ID

sub zenEndUserUpdate {
	
	my $zenUserName = $_[0];
	my $zenUserEmail = $_[1];
	my $zenUserPhone = $_[2];
	my $zenUserMactiveID = $_[3];
	
	my $user_id = zenEndUserIdByEmail ( $zenUserEmail );
	
	my $zen_json_object = "'{\"user\":{\"name\":\"$zenUserName\",\"email\":\"$zenUserEmail\",\"verified\":true,\"external_id\":\"$zenUserMactiveID\",\"phone\":\"$zenUserPhone\"}}'";


	my $auth_ = '\'lsaunder@acsmi.com/token:FdUcwJBqHkMf6JnVT5imQv9GF087uHbPy8ZwuDzd\'';
	
	# If the user exists, update the user. If the user doesn't exist, create it.
	my $query_ = '';
	my $curlstring = '';
	if ( $user_id ) { 
		$query_ = "'https://acsmiclass.zendesk.com/api/v2/users/$user_id.json'"; 
		$curlstring = "/usr/bin/curl --header 'Content-Type: application/json' --request PUT --user $auth_ --data $zen_json_object $query_";
	}
	else { 
		$query_ = "'https://acsmiclass.zendesk.com/api/v2/users.json'"; 
		$curlstring = "/usr/bin/curl --header 'Content-Type: application/json' --request POST --user $auth_ --data $zen_json_object $query_";		
	}
	
	print "$curlstring\n\n";
	
	my $response = `$curlstring`;

	print "$response \n\n";

}


return 1;

#	

#### End of Function definitions  ####

#### Start of loose code  ####
	#open ( FOUT, ">>./ad_riders.txt");
	#print FOUT "Processing Ad Riders.. \n";

					#print FOUT "schedule_: $schedule_ startday_: $startday_\n";
					#print FOUT "$positionString\n";
					
							#print FOUT "pushing rider: $rider_\n";
							#print FOUT 	"pushing rider: Ad_1_has_buyer_2ad_2id_is_$_[0][1]digital$ad_num";															

#Ad_has_ad_2type_is_{{ticket.ticket_field_option_title_21484610}}
#Ad_has_AdLocInfo_has_publication_is_{{ticket.ticket_field_option_title_21326184}}
#Ad_has_AdLocInfo_has_publication_2placement_is_{{ticket.ticket_field_option_title_21484630}}
#Ad_has_AdLocInfo_has_publication_2position_is_{{ticket.ticket_field_option_title_21484640}}
 #remove last if more than one ad per ticket

#### End of lost code  ####
