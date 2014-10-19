#!/usr/bin/perl

use strict;
use DBI;

my $dbh = DBI->connect('dbi:mysql:rat', 'kraknet', '') or die "could not access DB";
my $user = $ENV{kraknet_user};
my $perm = $ARGV[0] // 0;

if(length($user) == 0){
	# Not logged in!
	print "<!-- Not logged in... -->";
	exit 0
}

my $sql = qq{
	SELECT s.id_stack, s.name, s.date, s.creator
	FROM stack AS s
	LEFT JOIN userstack AS us ON us.id_stack = s.id_stack
	LEFT JOIN user AS u ON u.id_user = us.id_user
	WHERE u.name = ? AND us.permission = ?;
};
my $sth = $dbh->prepare($sql);

# Get all links in all stacks that krakissi is the owner of.
$sth->execute($user, $perm);

print "<ul>\n";
my $count = 0;
while(my ($id, $name, $date, $creator) = $sth->fetchrow_array()){
	print "\t<li>$id: $name ($creator at $date)</li>\n";
	$count++;
}
print "</ul>\n";

# Uh oh, no stacks!
if(!$count){
	print qq{<h3>No stacks here.</h3>};
}

exit 0
