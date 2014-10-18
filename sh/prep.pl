#!/usr/bin/perl
# mperron (2014)
#
# First-run preparations if the current user is not in the database.

use strict;
use DBI;

my $dbh = DBI->connect('dbi:mysql:rat', 'kraknet', '') or die "could not access DB";


my $user = $ENV{kraknet_user};
if(length($user) == 0){
	# Not logged in!

	# FIXME debug
	print "<!-- User not logged in. -->";
}

# Insert into the databse...ignore if the value already exists (names in this table are unique).
my $sql = qq{
	INSERT IGNORE INTO user(name) VALUES(?);
};
my $sth = $dbh->prepare($sql);
$sth->execute($user);

print "<!-- Hi, $user! -->";

exit 0
