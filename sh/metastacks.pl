#!/usr/bin/perl
# metastacks
# mperron (2014)
#
# Top n most recent links from all stacks.

use strict;
use DBI;
require KrakratCommon;

my $dbh = DBI->connect('dbi:mysql:rat', 'kraknet', '') or die "could not access DB";
my $user = $ENV{kraknet_user};
my $perm = $ARGV[0] // -1;
my $size = $ARGV[1] // 10;

if(length($user) == 0){
	# Not logged in!
	print "<!-- Not logged in... -->";
	exit 0
}

my $count = KrakratCommon::getlinks(undef, 10);

# Uh oh, no stacks!
if(!$count){
	print qq{<h3>No stacks here.</h3>};
}

exit 0
