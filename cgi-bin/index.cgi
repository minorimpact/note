#!/usr/bin/perl

use MinorImpact;

use note;

my $MI = new MinorImpact({https=>1, validUser=>1, config_file=>"../conf/minorimpact.conf"});
$MI->cgi({script=>'index'});
