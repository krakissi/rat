#!/usr/bin/perl
# search_form
# mperron (2017)
#
# Generates the HTML form whose action searches for links.

use strict;
use lib '.';
require KrakratCommon;

my %queryvals = KrakratCommon::query();

print qq{
	<h2>Search</h2>
	<form id=search_field name=search action=/search.html>
		<label for=search_field_q>Query</label>
		<input id=search_field_q type=text name=q value="} . KrakratCommon::escape_link($queryvals{q}) . qq{" autofocus>
		<input type=submit value=Search>
	</form>
};

exit 0
