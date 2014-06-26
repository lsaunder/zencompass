#!/usr/bin/perl -w
use strict;
use warnings;

require "./zenxml-functions.pl";

separate_xml_orders ( $ARGV[0] );

exit(0);