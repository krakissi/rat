#!/usr/bin/perl
# Common
# mperron (2014)
#
# Common krakrat functionality.

package KrakratCommon;

use strict;
use DBI;

# getlinks
# Used to create tables of links in a stack.
{
	my $l;
	my $dbh = DBI->connect('dbi:mysql:rat', 'kraknet', '') or die "could not access DB";
	my $sth = &prepare(3);

	# Get links. Requires stack ID. Optional limit value will limit the return to n links.
	sub getlinks {
		my %param = %{@_[0]};
		my $id_stack = $param{id_stack};
		my $limit = $param{limit};
		my $user = $param{id_user};
		my $headings = $param{headings};
		my $controls = $param{controls};

		my $count = 0;

		# Limit value has changed, rebuild prepared statement...
		$sth = &prepare($id_stack, $limit) if(!$limit || ($limit != $l));

		if($id_stack){
			$sth->execute($id_stack);
		} elsif($user){
			$sth->execute($user);
		}

		print qq{<input type=hidden name=stack value="$id_stack">\n} if($controls && $id_stack);
		print "\t<table>\n";
		print "\t\t<thead><tr><th>Stack</th><th>Date</th><th>Link</th></tr></thead>\n" if($headings);
		while(my ($id_link, $uri, $short, $meta, $date, $stack, $id_stack) = $sth->fetchrow_array()){
			my $display = (length($meta) > 0) ? $meta : $uri;

			$stack = &escape_html($stack);
			$date = &escape_html($date);
			$uri = &escape_link($uri);
			$display = &escape_html($display);
			my $short_uri = &escape_link($short);
			$short = &escape_html($short);

			print qq{\t\t<tr>} . ($controls ? qq{<td><input type=checkbox name=link value="$id_link">} : "") . ($stack ? qq{<td><a href="stack.html?id=$id_stack">$stack</a></td>} : "") . qq{<td>$date</td><td><a href="$uri" target=_blank>$display</a></td>};
			print qq{<td><a href="$short_uri">$short</a></td>} if(length($short));
			print qq{</tr>\n};
			$count++;
		}
		print "\t</table>\n";

		return $count;
	}

	# Build the prepared statement for getting links.
	sub prepare {
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

		return $dbh->prepare($sql);
	}
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


# Returning a true value...perl pls.
1
