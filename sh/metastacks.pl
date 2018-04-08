#!/usr/bin/perl
# metastacks
# mperron (2014)
#
# Top n most recent links from all stacks.

use strict;
use DBI;
use lib '.';
require KrakratCommon;

my $user = $ENV{kraknet_user};
my $size = $ARGV[0] // 20;

if(!length($user)){
	# Not logged in!
	print "<!-- Not logged in... -->";
	exit 0
}

my $count = KrakratCommon::getlinks({ limit => $size, id_user => $user });

# Uh oh, no stacks!
print qq{<h3>No links here.</h3>} if(!$count);

exit 0
