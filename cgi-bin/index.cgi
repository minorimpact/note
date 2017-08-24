#!/usr/bin/perl

use MinorImpact;
use MinorImpact::Util;

use note;

my $MI = new MinorImpact({ https => 1 });
$MI->www({ actions => { archive => \&archive, edit => \&edit, home => \&home } });

sub archive {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");
    my $CGI = $MINORIMPACT->cgi();

    my $collection_id = $CGI->param('collection_id') || $CGI->param('cid');
    my $object_id = $CGI->param('object_id') || $CGI->param('id') || $MINORIMPACT->redirect();
    my $search = $CGI->param('search');
    my $user = $MINORIMPACT->user({ force => 1 });
    my $settings = $user->settings();

    my $object = new MinorImpact::Object($object_id) || $MINORIMPACT->redirect();

    my @tags = $object->tags();
    if (grep { /^new$/ } @tags) {
        @tags = grep { !/^new$/; } $object->tags();
    } else {
        push(@tags, $settings->get('default_tag'));
    }

    #MinorImpact::log(8, "\@tags='" . join(",", @tags) . "'");
    $object->update({ tags => join(",", @tags) });

    $MINORIMPACT->redirect({ action => 'home', collection_id => $collection_id, search => $search });
}

sub edit {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    $params->{no_name} = 1;
    MinorImpact::WWW::edit($MINORIMPACT, $params);
}

sub home {
    my $MINORIMPACT = shift || return;
    my $params = shift ||{};

    my $CGI = MinorImpact::cgi();
    my $user = MinorImpact::user({ force => 1 });

    my $search = $CGI->param('search');
    my $collection_id = $CGI->param('cid');
    my $object_type_id = MinorImpact::Object::typeID('note');
    my $settings = $user->settings();

    my $local_params = cloneHash($params);
    $local_params->{query} = { 
                                %{$local_params->{query}},
                                debug => "note::index.cgi::index();", 
                                object_type_id => $object_type_id, 
                                user_id => $user->id(),
                            };
    unless ($collection_id || $search) {
        $local_params->{query}{tag} = $settings->get('default_tag');
    }
    return MinorImpact::WWW::home($MINORIMPACT, $local_params);
}

