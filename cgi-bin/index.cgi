#!/usr/bin/perl

use MinorImpact;
use MinorImpact::Util;

use note;

my $MI = new MinorImpact({ https => 1, config_file => "../conf/minorimpact.conf" });
$MI->cgi({ actions => { archive => \&archive, edit => \&edit, index => \&index } });

sub archive {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");
    my $CGI = $MINORIMPACT->getCGI();

    my $collection_id = $CGI->param('collection_id') || $CGI->param('cid');
    my $object_id = $CGI->param('object_id') || $CGI->param('id') || $MINORIMPACT->redirect();
    my $search = $CGI->param('search');

    my $object = new MinorImpact::Object($object_id) || $MINORIMPACT->redirect();

    my @tags = grep { !/new/; } $object->getTags();
    #MinorImpact::log(8, "\@tags='" . join(",", @tags) . "'");
    $object->update({ tags => join(",", @tags) });

    $MINORIMPACT->redirect("?cid=$collection_id&search=$search");
}

sub edit {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    # I'm not sure how I feel about this... in some ways, it's very much like the
    #   object functions that override the defaults, set up something only they care
    #   about and then call the parent, but this is... this feels hinky some how,
    #   but that might just be because I literally just thought of this implementation
    #   and I haven't had time to consider the ramifications.
    #
    # NOTE: it's just as effective to pass the no_name parameter in the parameters
    #   to the cgi() function, and probably more straightforward and easier, but I'm
    #   leaving it this way to remind myself of the technique.
    #
    # TODO: Figure out a better way to do this inside the object itself; it seems 
    #   dumb to have index.cgi responsible for the inner workings of the objects.
    #   In fact, it's dumb to have any of these functions here, they should own 
    #   these functions and register them with the main global MinorImpact object
    #   at some point when they're instantiated for the first time.
    
    $params->{no_name} = 1;
    MinorImpact::CGI::edit($MINORIMPACT, $params);
}

sub index {
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
    return MinorImpact::CGI::index($MINORIMPACT, $local_params);
}

