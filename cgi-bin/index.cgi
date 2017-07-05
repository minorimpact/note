#!/usr/bin/perl

use MinorImpact;

use note;

my $MI = new MinorImpact({https=>1, valid_user=>1, config_file=>"../conf/minorimpact.conf"});
$MI->cgi({ script => 'index', actions => {archive => \&archive }, tag=>'new' });

sub archive {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");
    my $CGI = $MINORIMPACT->getCGI();

    my $object_id = $CGI->param('object_id') || $CGI->param('id') || $MINORIMPACT->redirect();
    my $container_id = $CGI->param('container_id') || $CGI->param('cid');

    my $object = new MinorImpact::Object($object_id) || $MINORIMPACT->redirect();

    my @tags = grep { !/new/; } $object->getTags();
    #MinorImpact::log(8, "\@tags='" . join(",", @tags) . "'");
    $object->update({ tags => join(",", @tags) });

    $MINORIMPACT->redirect("?cid=$container_id");
}
