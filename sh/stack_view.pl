#!/usr/bin/perl
# stack_view
# mperron (2014)
#
# View the full contents of an individual stack.
# Retrives the stack ID from the query string.

use strict;
use DBI;

my %has;
my $dbh = DBI->connect('dbi:mysql:rat', 'kraknet', '') or die "could not access DB";
my $user = $ENV{kraknet_user};

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

my $id_stack = $queryvals{id};
if(!($id_stack =~ /^[0-9]*$/)){
	# Stack ID is invalid! 420bailit.
	print "<!-- Invalid stack ID: '$id_stack' -->\n";
	exit 0
}

my $sql = qq{
	SELECT s.name, s.creator, s.date, s.public
	FROM stack AS s
	WHERE s.id_stack = ?;
};
my $sth = $dbh->prepare($sql);
$sth->execute($id_stack);
my ($name, $creator, $date, $public) = $sth->fetchrow_array();
$has{read} = 1 if($public == 1);

if(length($user) > 0){
	# User is logged in; check for permissions on this stack.
	$sql = qq{
		SELECT us.permission
		FROM userstack AS us
		WHERE us.id_user = (SELECT u.id_user FROM user AS u WHERE u.name = ?)
			AND us.id_stack = ?;
	};
	$sth = $dbh->prepare($sql);
	$sth->execute($user, $id_stack);
	my ($perm) = $sth->fetchrow_array();

	if(($perm == 0) || ($perm == 1)){
		# Contributor or owner of this stack.
		$has{read} = 1;
		$has{write} = 1;
	} elsif($perm == 2){
		# Reader of this stack only.
		$has{read} = 1;
	}
}

if($has{read}){
	print "<h2>$name</h2>\n";

	$sql = qq{
		SELECT l.uri, l.short, l.meta, l.date
		FROM link AS l
		LEFT JOIN stacklink AS sl ON sl.id_link = l.id_link
		WHERE sl.id_stack = ?
		ORDER BY l.date DESC;
	};
	$sth = $dbh->prepare($sql);
	$sth->execute($id_stack);

	# Dump out the links!
	print "<ul>\n";
	while(my ($uri, $short, $meta, $date) = $sth->fetchrow_array()){
		print qq{\t<li><a href="$uri" title="$meta" target=_blank>$uri</a>};

		# Short variant of the link, if available.
		if(length($short) > 0){
			print qq{ - <a href="$short">$short</a>};
		}

		print qq{</a></li>\n};
	}
	print "</ul>\n";
}

exit 0
