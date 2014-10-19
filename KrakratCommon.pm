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

		my $count = 0;

		# Limit value has changed, rebuild prepared statement...
		$sth = &prepare($id_stack, $limit) if(!$limit || ($limit != $l));

		if($id_stack){
			$sth->execute($id_stack);
			print "\t<table>\n";
			while(my ($uri, $short, $meta, $date) = $sth->fetchrow_array()){
				my $display = (length($meta) > 0) ? $meta : $uri;

				print qq{\t\t<tr><td>$date</td><td><a href="$uri" target=_blank>$display</a></td>};
				print qq{<td><a href="$short">$short</a></td>} if(length($short) > 0);
				print qq{</tr>\n};
				$count++;
			}
			print "\t</table>\n";
		} elsif($user){
			$sth->execute($user);
			print "\t<table>\n";
			while(my ($uri, $short, $meta, $date, $stack) = $sth->fetchrow_array()){
				my $display = (length($meta) > 0) ? $meta : $uri;

				print qq{\t\t<tr><td>$stack</td><td>$date</td><td><a href="$uri" target=_blank>$display</a></td>};

				if(length($short) > 0){
					print qq{<td><a href="$short">$short</a></td>};
				}

				print qq{</tr>\n};
				$count++;
			}
			print "\t</table>\n";
		}

		return $count;
	}

	# Build the prepared statement for getting links.
	sub prepare {
		my $id_stack = shift;
		$l = shift;

		my $sql;
		if($id_stack){
			$sql = qq{
				SELECT l.uri, l.short, l.meta, l.date
				FROM link AS l
				LEFT JOIN stacklink AS sl ON sl.id_link = l.id_link
				WHERE sl.id_stack = ?
				ORDER BY l.date DESC
			} . ($l ? "LIMIT $l;" : ";");
		} else {
			# No id_stack value means to select from all stacks the user can read.
			$sql = qq{
				SELECT l.uri, l.short, l.meta, l.date, s.name
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
