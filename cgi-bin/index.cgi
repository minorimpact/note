#!/usr/bin/perl

use MinorImpact;
use MinorImpact::Util;

use note;

my $MI = new MinorImpact({ https => 1 });
$MI->cgi({ actions => { archive => \&archive, edit => \&edit, home => \&home } });

sub archive {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");
    my $CGI = $MINORIMPACT->getCGI();

    my $collection_id = $CGI->param('collection_id') || $CGI->param('cid');
    my $object_id = $CGI->param('object_id') || $CGI->param('id') || $MINORIMPACT->redirect();
    my $search = $CGI->param('search');

    my $object = new MinorImpact::Object($object_id) || $MINORIMPACT->redirect();

    my @tags = $object->getTags();
    if (grep { /^new$/ } @tags) {
        @tags = grep { !/^new$/; } $object->getTags();
    } else {
        push(@tags, "new");
    }

    #MinorImpact::log(8, "\@tags='" . join(",", @tags) . "'");
    $object->update({ tags => join(",", @tags) });

    $MINORIMPACT->redirect("?a=home&cid=$collection_id&search=$search");
}

sub edit {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    $params->{no_name} = 1;
    MinorImpact::CGI::edit($MINORIMPACT, $params);
}

sub home {
    my $MINORIMPACT = shift || return;
    my $params = shift ||{};

    my $CGI = MinorImpact::getCGI();
    my $TT = MinorImpact::getTT();
    my $user = MinorImpact::getUser({ force => 1 });

    my $search = $CGI->param('search');
    my $collection_id = $CGI->param('cid');
    my $type_id = MinorImpact::Object::typeID('note');

    my $local_params = cloneHash($params);
    $local_params->{query} = { 
                                %{$local_params->{query}},
                                debug => "note::index.cgi::index();", 
                                object_type_id=>$type_id, 
                                user_id => $user->id(),
                            };
    unless ($collection_id || $search) {
        $local_params->{query}{tag} = "new";
    }
    return MinorImpact::CGI::home($MINORIMPACT, $local_params);
}

