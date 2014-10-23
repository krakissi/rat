#!/usr/bin/perl

use strict;
use DBI;
require KrakratCommon;

my $dbh = KrakratCommon::get_connection();
my $user = $ENV{kraknet_user};
my $perm = $ARGV[0] // 0;
my %creators;

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
$sth->execute($user, $perm);

print "<ul>\n";
my $count = 0;
while(my ($id, $name, $date, $creator) = $sth->fetchrow_array()){
	my $cname = &creator_find($creator);

	$name = KrakratCommon::escape_html($name);
	print qq{\t<li><a href="stack.html?id=$id" title="Created by $cname ($date)">$name</a>\n};

	# Display first three links
	KrakratCommon::getlinks({ id_stack => $id, limit => 3, no_date => 1 });

	print qq{\t</li>\n};
	$count++;
}
print "</ul>\n";

# Uh oh, no stacks!
print qq{<h3>No stacks here.</h3>} if(!$count);

# Find the name from a user ID.
sub creator_find {
	my $id_user = shift;
	return undef if(!$id_user);

	my $cname = $creators{$id_user};

	if(!$cname){
		my $sql = qq{
			SELECT u.name
			FROM user AS u
			WHERE u.id_user = ?;
		};
		my $sth = $dbh->prepare($sql);
		$sth->execute($id_user);
		($cname) = $sth->fetchrow_array();
		$creators{$id_user} = $cname;
	}

	return $cname;
}

exit 0
