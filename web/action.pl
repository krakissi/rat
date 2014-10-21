#!/usr/bin/perl
# action
# mperron (2014)
#
# Performs actions based on POST values.

use strict;
use URI::Escape;
use DBI;

my $referer = $ENV{HTTP_REFERER} // "/";

# Locate KrakratCommon module
chomp(my $home = qx/mod_home rat/);
eval "require '$home/KrakratCommon.pm';";

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
} elsif($op eq "stack_edit"){
	&stack_edit({
		id_stack => $postvalues{stack},
		name => $postvalues{name},
		owner => $postvalues{owner},
		public => $postvalues{public}
	});
} elsif($op eq "stack_remove"){
	&stack_remove($postvalues{stack});
} elsif($op eq "link_add"){
	&link_add($postvalues{stack}, $postvalues{uri}, $postvalues{meta});
} elsif($op eq "link_remove"){
	foreach my $link (@links){
		&link_remove($link, $postvalues{stack});
	}
}

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

# Alter a stack; only the owner may do this.
sub stack_edit {
	my %params = %{@_[0]};
	my $id_stack = $params{id_stack};
	my $name = $params{name};
	my $owner = $params{owner};
	my $public = $params{public};

	my %has = KrakratCommon::permissions({ id_stack => $id_stack, user => $user });
	my $info = $has{info};

	# Only the owner can edit the stack meta (name, permissions, etc.)
	if($has{owner}){
		if(length($name)){
			my $sql = qq{
				UPDATE stack
				SET name = ?
				WHERE id_stack = ?;
			};
			my $sth = $dbh->prepare($sql);
			$sth->execute($name, $id_stack);
		}
		if(length($public) && (($public == 0) || ($public == 1))){
			my $sql = qq{
				UPDATE stack
				SET public = ?
				WHERE id_stack = ?;
			};
			my $sth = $dbh->prepare($sql);
			$sth->execute($public, $id_stack);
		}
		if(length($owner)){
			# TODO Changing ownership
		}
	}
}

# Remove the specified stack (id_stack val) and all associated links permanently; only the owner may do this.
sub stack_remove {
	my $id_stack = shift;
	return 1 if(!length($id_stack));

	my %has = KrakratCommon::permissions({ id_stack => $id_stack, user => $user });
	my $info = $has{info};

	if($has{owner}){
		# Find all links in this stack.
		my $sql = qq{
			SELECT id_link
			FROM stacklink
			WHERE id_stack = ?;
		};
		my $sth = $dbh->prepare($sql);
		$sth->execute($id_stack);

		# Remove links which are exclusive to this stack, and all stacklink references.
		while(my ($id_link) = $sth->fetchrow_array()){
			&link_remove($id_link, $id_stack);
		}

		# Delete the stack.
		$sql = qq{
			DELETE FROM stack
			WHERE id_stack = ?;
		};
		$sth = $dbh->prepare($sql);
		$sth->execute($id_stack);

		$sql = qq{
			DELETE FROM userstack
			WHERE id_stack = ?;
		};
		$sth = $dbh->prepare($sql);
		$sth->execute($id_stack);

		# Alter referer; the stack is no longer a safe place to return to.
		$referer = "/" if($referer =~ /\/stack\.html.*\?id=/);
	}
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
		FROM stacklink AS sl
		LEFT JOIN stack AS s ON s.id_stack = sl.id_stack
		LEFT JOIN userstack AS us ON us.id_stack = s.id_stack
		WHERE us.id_user = ? AND sl.id_link = ?;
	};
	my $sth = $dbh->prepare($sql);
	$sth->execute($id_user, $id_link);

	# Remove references from stacklink
	while(my ($perm, $addedby, $stack) = $sth->fetchrow_array()){
		return 1 if(!length($perm));
		if(($perm == 0) || ($perm == 1)){
			# Only remove if addedby id_user.
			return 1 if(($perm == 1) && ($id_user != $addedby));

			if(length($stack) && ($stack == $id_stack)){
				$sql = qq{
					DELETE FROM stacklink
					WHERE id_link = ? AND id_stack = ?;
				};
				my $sth = $dbh->prepare($sql);
				$sth->execute($id_link, $id_stack);
			} else {
				$sql = qq{
					DELETE FROM stacklink
					WHERE id_link = ?;
				};
				my $sth = $dbh->prepare($sql);
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
	print "Status: 302 Unauthorized\nLocation: $referer\n\n";
	exit 0
}
