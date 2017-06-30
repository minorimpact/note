#!/usr/bin/perl

use MinorImpact;

my $MINORIMPACT = new MinorImpact({validUser=>1, https=>1});
$MINORIMPACT->cgi({script=>'tags'});


