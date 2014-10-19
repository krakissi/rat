#!/usr/bin/perl
# stack_view
# mperron (2014)
#
# View the full contents of an individual stack.
# Retrives the stack ID from the query string.

use strict;
use DBI;
require KrakratCommon;

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

	if(length($perm) == 0){
		# No additional permissions.
	} elsif($perm == 0){
		# Owner of this stack (can change visibility permissions).
		$has{read} = 1;
		$has{write} = 1;
		$has{owner} = 1;
	} elsif($perm == 1){
		# Contributor to this stack.
		$has{read} = 1;
		$has{write} = 1;
	} elsif($perm == 2){
		# Reader of this stack only.
		$has{read} = 1;
	}
}

# Edit controls, for adding new links.
if($has{write}){
	print qq{
	<div>
		<form action=action.pl method=post>
			<input type=hidden name=op value=link_add>
			<input type=hidden name=stack value="$id_stack">

			<label for=link_add_uri>URL</label>
			<input id=link_add_uri name=uri><br>

			<label for=link_add_meta>Title</label>
			<input id=link_add_meta name=meta><br>

			<input type=submit value=Push>
			<input type=reset value=Clear>
		</form>
	</div>};
}

if($has{owner}){
	print qq{
	<div>
		<p>You are the owner of this stack.</p>
	</div>
	};
}

if($has{read}){
	print "<h2>$name</h2>\n";

	# Dump out the links!
	my $count = KrakratCommon::getlinks({id_stack => $id_stack});

	print "<h3>This stack has no links.</h3>\n" if(!$count);
} else {
	print "<p>You do not have permission to view this stack.</p>";
}

exit 0
