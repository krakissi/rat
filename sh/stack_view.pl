#!/usr/bin/perl
# stack_view
# mperron (2014)
#
# View the full contents of an individual stack.
# Retrives the stack ID from the query string.

use strict;
use DBI;
use KrakratCommon;

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

my %has = KrakratCommon::permissions({ id_stack => $id_stack, user => $user });
my %info = $has{info};

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
	my $name = KrakratCommon::escape_html($info{name});
	print "<h2>$name</h2>\n";
	print qq{<form action=action.pl method=post id=form_remove>\n<input type=hidden name=op value=link_remove>\n};

	# Dump out the links!
	my $count = KrakratCommon::getlinks({id_stack => $id_stack, controls => 1});

	print qq{<input type=submit value="Remove Selected"><input type=reset value="Unselect All"></form>\n};
	print "<h3>This stack has no links.</h3>\n" if(!$count);
} else {
	print "<p>You do not have permission to view this stack.</p>";
}

exit 0
