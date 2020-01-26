# KrakratCommon
# mperron (2014)
#
# Common krakrat functionality.

package KrakratCommon;

use strict;
use DBI;

# Get Database connection.
sub get_connection {
	return DBI->connect('dbi:mysql:rat', 'kraknet', '') or die "could not access DB";
}

# Database depedent subroutines are in this controlled scope.
{
	my $l;
	my $dbh = &get_connection();
	my $sth_getlinks;

	# Get links. Requires stack ID. Optional limit value will limit the return to n links.
	sub getlinks {
		my %param = %{@_[0]};
		my $id_stack = $param{id_stack};
		my $limit = $param{limit};
		my $user = $param{id_user};
		my $controls = $param{controls};
		my $no_date = $param{no_date};

		my $count = 0;

		# Limit value has changed, rebuild prepared statement...
		$sth_getlinks = &getlinks_prepare($id_stack, $limit) if(!$limit || ($limit != $l));

		if($id_stack){
			$sth_getlinks->execute($id_stack);
		} elsif($user){
			$sth_getlinks->execute($user);
		}

		print qq{<input type=hidden name=stack value="$id_stack">\n} if($controls && $id_stack);
		print "\t<table class=links_table>\n";
		while(my ($id_link, $uri, $short, $meta, $date, $stack, $id_stack) = $sth_getlinks->fetchrow_array()){
			my $display = (length($meta) > 0) ? $meta : $uri;

			$stack = &escape_html($stack);
			$date = &escape_html($date);
			$uri = &escape_link($uri);
			$display = &escape_html($display);
			my $short_uri = &escape_link($short);
			$short = &escape_html($short);

			print qq{\t\t<tr>} .
				($controls ? qq{<td><input type=checkbox name=link value="$id_link">} : "") .
				($stack ? qq{<td><a href="stack.html?id=$id_stack">$stack</a></td>} : "") .
				($no_date ? "" : qq{<td>$date</td>}) .
				qq{<td class=view_link_anchor><a href="$uri" title="$uri" target=_blank id-link="$id_link">$display</a></td>};

			print qq{<td><a href="$short_uri">$short</a></td>} if(length($short));
			print qq{</tr>\n};
			$count++;
		}
		print "\t</table>\n";

		return $count;
	}

	# Build the prepared statement for getting links.
	sub getlinks_prepare {
		my $id_stack = shift;
		$l = shift;

		my $sql;
		if($id_stack){
			$sql = qq{
				SELECT l.id_link, l.uri, l.short, l.meta, l.date
				FROM link AS l
				LEFT JOIN stacklink AS sl ON sl.id_link = l.id_link
				WHERE sl.id_stack = ?
				ORDER BY l.date DESC
			} . ($l ? "LIMIT $l;" : ";");
		} else {
			# No id_stack value means to select from all stacks the user can read.
			$sql = qq{
				SELECT l.id_link, l.uri, l.short, l.meta, l.date, s.name, s.id_stack
				FROM link AS l
				LEFT JOIN stacklink AS sl ON sl.id_link = l.id_link
				LEFT JOIN stack AS s ON s.id_stack = sl.id_stack
				LEFT JOIN userstack AS us ON us.id_stack = s.id_stack
				LEFT JOIN user AS u ON u.id_user = us.id_user
				WHERE u.name = ?
				ORDER BY l.date DESC
			} . ($l ? "LIMIT $l;" : ";");
		}

		$sth_getlinks = $dbh->prepare($sql);
	}

	# Find permissions that a user has on a given stack.
	sub permissions {
		my %params = %{@_[0]};
		my $id_stack = $params{id_stack};
		my $user = $params{user};

		# The eventual return value. What permissions does the user have?
		my %has;

		if(length($id_stack)){
			my $sql = qq{
				SELECT s.name, s.creator, s.date, s.public
				FROM stack AS s
				WHERE s.id_stack = ?;
			};
			my $sth = $dbh->prepare($sql);
			$sth->execute($id_stack);
			my ($name, $creator, $date, $public) = $sth->fetchrow_array();
			$has{read} = 1 if($public == 1);

			my $info = {
				name => $name,
				creator => $creator,
				date => $date,
				public => $public
			};
			$has{info} = $info;

			if(length($user)){
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

				if(!length($perm)){
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
		}

		return %has;
	}
}

sub query {
	my $buffer = $ENV{QUERY_STRING};
	my %queryvals;

	if(length($buffer) > 0){
		my @pairs = split(/[;&]/, $buffer);
		foreach my $pair (@pairs){
			my ($name, $value) = split(/=/, $pair);
			$name =~ s/^\s+//;
			$value =~ s/\+/ /g;
			$value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
			chomp($queryvals{$name} = $value);
		}
	}

	return %queryvals;
}

# Escape quotes for quoted strings.
sub escape_link {
	my $link = shift;
	$link =~ s/"/&quot;/g if($link);

	return $link;
}

# Escape HTML for generic display.
sub escape_html {
	my $link = shift;
	if($link){
		$link =~ s/&/&amp;/g;
		$link =~ s/</&lt;/g;
		$link =~ s/>/&gt;/g;
	}

	return $link;
}

# Generic redirect page
sub do_redirect {
	my %p = %{@_[0]};
	my $target = $p{target} // '/';

	my $target_quot = &escape_link($target);
	my $target_html = &escape_html($target);

	print qq{Content-Type: text/html; charset=utf-8

<!DOCTYPE html>
<html><head>
	<title>Redirecting...</title>
	<meta http-equiv="refresh" content="0;$target_quot">
</head><body>
	<p>Redirecting you to <a href="$target_quot">$target_html</a>...</p>
</body></html>
	};
}


# Load up for a default of 3 links previewed per stack.
&getlinks_prepare(3);

# Returning a true value...perl pls.
1
