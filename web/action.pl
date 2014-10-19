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

# Used for selecting multiple links.
my @links;

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

		push(@links, $value) if($name eq "link");
	}
}

my $op = $postvalues{op};

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
} elsif($op eq "link_remove"){
	foreach my $link (@links){
		&link_remove($link, $postvalues{stack});
	}
}

my $referer = $ENV{HTTP_REFERER} // "/";
print "Status: 302 Operation\nLocation: $referer\n\n";
exit 0;

# Create a new stack. 1 parameter, the vanity name of the stack.
sub stack_create {
	my $name = shift;
	return 1 if(!length($name));

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
	return 1 if(!length($uri));

	# Find stack by id and check permission of user. Must be 0 or 1 to add.
	my $sql = qq{
		SELECT us.permission, s.creator
		FROM stack AS s
		LEFT JOIN userstack as us ON us.id_stack = s.id_stack
		WHERE us.id_user = ? AND us.id_stack = ?;
	};
	my $sth = $dbh->prepare($sql);
	$sth->execute($id_user, $id_stack);
	my ($perm, $creator) = $sth->fetchrow_array();

	return 1 if(!length($perm));
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

sub link_remove {
	my ($id_link, $id_stack) = @_;
	return 1 if(!$id_link);

	# Find out if the user has permission to modify the stack this link is in.
	my $sql = qq{
		SELECT us.permission, sl.addedby, sl.id_stack
		FROM link AS s
		LEFT JOIN stacklink AS sl ON sl.id_link = l.id_link
		LEFT JOIN stack AS s ON s.id_stack = sl.id_stack
		LEFT JOIN userstack AS us ON us.id_stack = s.id_stack
		WHERE us.id_user = ?;
	};
	my $sth = $dbh->prepare($sql);
	$sth->execute($id_user);

	# Remove references from stacklink
	while(my ($perm, $addedby, $stack) = $sth->fetchrow_array()){
		return 1 if(!length($perm));
		if(($perm == 0) || ($perm == 1)){
			# Only remove if addedby id_user.
			return 1 if(($perm == 1) && ($id_user != $addedby));

			if($stack && ($stack == $id_stack)){
				$sql = qq{
					DELETE FROM stacklink
					WHERE id_link = ? AND id_stack = ?;
				};
				$sth = $dbh->prepare($sql);
				$sth->execute($id_link, $id_stack);
			} else {
				$sql = qq{
					DELETE FROM stacklink
					WHERE id_link = ?;
				};
				$sth = $dbh->prepare($sql);
				$sth->execute($id_link);
			}
		}
	}

	# Are there any references left in stacklink?
	$sql = qq{
		SELECT count(*)
		FROM stacklink
		WHERE id_link = ?;
	};
	$sth = $dbh->prepare($sql);
	$sth->execute();
	my ($count) = $sth->fetchrow_array();

	# If no more references, delete from link.
	if(!$count){
		$sql = qq{
			DELETE FROM link
			WHERE id_link = ?;
		};
		$sth = $dbh->prepare($sql);
		$sth->execute($id_link);
	}
}

sub unauthorized {
	print "Status: 401 Unauthorized\n\n";
	exit 0
}
