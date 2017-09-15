#!/usr/bin/perl
# loginctl
# mperron (2014)
#
# Show "login" or "logout", depending on user state

use strict;

my $user = $ENV{kraknet_user};
chomp(my $authdomain = qx/mod_find accounts:authdomain/);

if(!length($user)){
	# Login
	print qq{<a href="//$authdomain/" target=_self>login</a>};
} else {
	# Logout
	print qq{<a href="//$authdomain/logout" target=_self>logout</a>};
}

exit 0
