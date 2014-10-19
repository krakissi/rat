#!/usr/bin/perl
# metastacks
# mperron (2014)
#
# Top n most recent links from all stacks.

use strict;
use DBI;

my $dbh = DBI->connect('dbi:mysql:rat', 'kraknet', '') or die "could not access DB";
my $user = $ENV{kraknet_user};
my $perm = $ARGV[0] // -1;
my $size = $ARGV[1] // 10;

if(length($user) == 0){
	# Not logged in!
	print "<!-- Not logged in... -->";
	exit 0
}

my $sql = qq{
	SELECT sl.id_stack, l.id_link, l.uri
	FROM link AS l
	LEFT JOIN stacklink AS sl ON l.id_link = sl.id_link
	LEFT JOIN stack AS s ON sl.id_stack = s.id_stack
	LEFT JOIN userstack AS us ON us.id_stack = s.id_stack
	LEFT JOIN user AS u ON u.id_user = us.id_user
	WHERE u.name = ?} . (($perm == -1) ?  '' : qq{ AND us.permission = ? }) . qq{
	ORDER BY l.date
	LIMIT ?;
};
my $sth = $dbh->prepare($sql);

# Get all links in all stacks that krakissi is the owner of.
if($perm == -1){
	$sth->execute($user, $size);
} else {
	$sth->execute($user, $perm, $size);
}

my $count = 0;
while(my @row = $sth->fetchrow_array()){
	my ($id_stack, $id_link, $uri) = @row;

	# Escape quotes in href, and HTML in the display portion.
	print qq{<li><a href="$uri">$id_stack: $id_link - $uri</a></li>};

	$count++;
}

# Uh oh, no stacks!
if(!$count){
	print qq{<h3>No stacks here.</h3>};
}

exit 0
