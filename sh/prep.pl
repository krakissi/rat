#!/usr/bin/perl
# mperron (2014)
#
# First-run preparations if the current user is not in the database.

use strict;
use DBI;
require KrakratCommon;

my $dbh = KrakratCommon::get_connection();
my $user = $ENV{kraknet_user};

if(length($user) == 0){
	# Not logged in!
	print "<!-- User not logged in. -->";
	exit 0
}

# Is the user in the database yet?
my $sql = qq{
	SELECT id_user FROM user WHERE name = ?;
};
my $sth = $dbh->prepare($sql);
$sth->execute($user);
my ($id) = $sth->fetchrow_array();

# No ID available; add the user to this database.
if(!length($id)){
	$sql = qq{
		INSERT INTO user(name) VALUES(?);
	};
	$sth = $dbh->prepare($sql);
	$sth->execute($user);
}

print "<!-- Hi, $user! -->";

exit 0
