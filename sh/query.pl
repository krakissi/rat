#!/usr/bin/perl
# query
# mperron (2014)
#
# Prints the value of an item in the query string.

use strict;

# Get QUERY_STRING
my $buffer = $ENV{QUERY_STRING};
my %queryvals;
if(length($buffer) > 0){
	my @pairs = split(/[;&]/, $buffer);
	foreach my $pair (@pairs){
		my ($name, $value) = split(/=/, $pair);
		$name =~ s/^\s+//;
		$value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
		chomp($queryvals{$name} = $value);
	}
}

print $queryvals{$ARGV[0] // ""};

exit 0
