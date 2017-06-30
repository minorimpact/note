#!/usr/bin/perl

use MinorImpact;

my $MINORIMPACT = new MinorImpact({validUser=>1, https=>1, config_file=>"../conf/minorimpact.conf"});
$MINORIMPACT->cgi({script=>'search'});


