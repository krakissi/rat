#!/usr/bin/perl
# query
# mperron (2014)
#
# Prints the value of an item in the query string.

use strict;
use lib '.';
require KrakratCommon;

# Get QUERY_STRING
my %queryvals = KrakratCommon::query();

print $queryvals{$ARGV[0] // ""};

exit 0
