#!/usr/bin/perl

use strict;
require KrakratCommon;

my %queryvals = KrakratCommon::query();

print qq{
	<h2>Search</h2>
	<form id=search_field name=search action=/search.html>
		<label for=search_field_q>Query</label>
		<input id=search_field_q type=text name=q value="} . KrakratCommon::escape_link($queryvals{q}) . qq{">
		<input type=submit value=Search>
	</form>
};

exit 0
