#!/usr/bin/perl

use strict;
use DBI;
require KrakratCommon;

my $dbh = KrakratCommon::get_connection();
my $user = $ENV{kraknet_user};

my %queryvals = KrakratCommon::query();

# determine id_user of $user
{
	my $sql = qq{
		SELECT u.id_user
		FROM user as u
		WHERE u.name = ?;
	};
	my $sth = $dbh->prepare($sql);
	$sth->execute($user);
	my ($id_user) = $sth->fetchrow_array();

	if(!$id_user){
		print "<p><i>You may not search anonymously.</i></p>\n";
		exit 1;
	}

	$dbh->do("set \@id_user = ?", undef, $id_user);
}


my $sql = qq{
	SELECT d.name, d.id_stack, c.meta, c.uri, c.date
	FROM stack as d
	LEFT JOIN stacklink AS b ON b.id_stack=d.id_stack
	LEFT JOIN userstack AS a ON a.id_stack=b.id_stack
	LEFT JOIN link AS c ON b.id_link=c.id_link
	WHERE a.id_user = \@id_user
	AND (
};
my $qcount = 0;
my @query = split(' ', $queryvals{q});
foreach my $q (@query){
	$q =~ s/\%/\\\%/g;
	$q = "%" . $q . "%";

	my $refname = "\@q$qcount";
	$dbh->do("set $refname = ?", undef, $q);

	if($qcount > 0){
		$sql .= "AND";
	}
	$sql .= qq{
		(c.uri LIKE $refname OR
		c.meta LIKE $refname)
	};

	$qcount++;
}

$sql .= qq{
	)
	ORDER BY c.meta, c.uri;
};

my $sth = $dbh->prepare($sql);
$sth->execute();

my $rcount = 0;
while(my ($stack_name, $id_stack, $meta, $uri, $date) = $sth->fetchrow()){
	if($rcount == 0){
		print "<div class=search_results><table>\n"
			. "<tr><th></th><th>Link</th><th>Date</th><th>Stack</th></tr>\n";
	}
	print "<tr><td>"
		. ($rcount + 1)
		. ".</td><td><a href=\""
		. KrakratCommon::escape_link($uri)
		. "\">"
		. KrakratCommon::escape_html((length($meta) > 0) ? $meta : $uri)
		. "</a></td><td>"
		. KrakratCommon::escape_html($date)
		. "</td><td><a href=\"stack.html?id=$id_stack\">"
		. KrakratCommon::escape_html($stack_name)
		. "</a></td></tr>\n";

	$rcount++;
}
if($rcount > 0){
	print "</table><p><i>$rcount result" . (($rcount == 1) ? "" : "s") . "</i>.</div>\n";
} else {
	print "<p><i>No results.</i></p>\n";
}

exit 0
