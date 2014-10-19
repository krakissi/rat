#!/usr/bin/perl
# action
# mperron (2014)
#
# Performs actions based on POST values.

use strict;
use URI::Escape;
use DBI;

my $dbh = DBI->connect('dbi:mysql:rat', 'kraknet', '') or die "could not access DB";

# Reject actions from unauthorized users (not logged in).
chomp(my $user = qx/mod_find accounts:auth/);
if(!($user =~ s/OK[\s](.*)/\1/)){
	&unauthorized();
}

# Read standard formatted POST data.
my %postvalues;
chomp(my $buffer = <STDIN>);
if(length($buffer) > 0){
	my @pairs = split(/[;&]/, $buffer);
	foreach my $pair (@pairs){
		my ($name, $value) = split(/=/, $pair);
		$value =~ s/\+/ /g;
		$value = uri_unescape($value);
		$postvalues{$name} = $value;
	}
}

my $op = $postvalues{op};

# FIXME debug
print "Content-Type: text/plain; charset=utf-8\n\n";

# FIXME debug
foreach my $key (keys %postvalues){
	print "$key: $postvalues{$key}\n";
}

# Find user ID (always useful).
my $sql = qq{
	SELECT u.id_user
	FROM user as u
	WHERE u.name = ?;
};
my $sth = $dbh->prepare($sql);
$sth->execute($user);
my ($id_user) = $sth->fetchrow_array();
&unauthorized() if(!$id_user);

# Possible operations
if($op eq "stack_create"){
	&stack_create($postvalues{name});
} elsif($op eq "link_add"){
	&link_add($postvalues{stack}, $postvalues{uri}, $postvalues{meta});
}


# Create a new stack. 1 parameter, the vanity name of the stack.
sub stack_create {
	my $name = shift;
	$name = $name // "";
	$name = "New Stack" if(!length($name));

	# Create the new stack.
	my $sql = qq{
		INSERT INTO stack(creator, name) VALUES(?, ?);
	};
	my $sth = $dbh->prepare($sql);
	$sth->execute($id_user, $name);

	# Link the user with the stack (permission level 0 (owner) is the default value).
	my $id = $dbh->{mysql_insertid};
	$sql = qq{
		INSERT INTO userstack(id_user, id_stack) VALUES(?, ?);
	};
	$sth = $dbh->prepare($sql);
	$sth->execute($id_user, $id);

	return 0
}

# Add a link to an existing stack, takes ID of stack and URI, plus optional link description (meta).
sub link_add {
	my ($id_stack, $uri, $meta) = @_;

	# Find stack by id and check permission of user. Must be 0 or 1 to add.
	my $sql = qq{
		SELECT us.permission, s.creator
		FROM stack as s
		LEFT JOIN userstack as us ON us.id_stack = s.id_stack
		WHERE us.id_user = ? AND us.id_stack = ?;
	};
	my $sth = $dbh->prepare($sql);
	$sth->execute($id_user, $id_stack);
	my ($perm, $creator) = $sth->fetchrow_array();

	if(($perm == 0) || ($perm == 1)){
		# Add link entry.
		$sql = qq{
			INSERT INTO link(uri, meta) VALUES(?, ?);
		};
		$sth = $dbh->prepare($sql);
		$sth->execute($uri, $meta);

		# Connect link to stack with stacklink entry.
		my $id_link = $dbh->{mysql_insertid};
		$sql = qq{
			INSERT INTO stacklink(id_stack, id_link, addedby) VALUES(?, ?, ?);
		};
		$sth = $dbh->prepare($sql);
		$sth->execute($id_stack, $id_link, $id_user);

		# Operation successful.
		return 0
	}

	# Something went wrong.
	return 1
}

sub unauthorized {
	print "Status: 401 Unauthorized\n\n";
	exit 0
}

exit 0
