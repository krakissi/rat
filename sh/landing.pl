#!/usr/bin/perl
# landing
# mperron (2014)
#
# Render the landing page!

use strict;

my $user = $ENV{kraknet_user};

if(length($user) > 0){
	# The "inline" renderer won't print HTTP headers.
	system("kraknet_inline layout/landing.html");
} else {
	# TODO login/register util should display here.
	print "<p>Soon&trade;</p>\n";
}

exit 0
