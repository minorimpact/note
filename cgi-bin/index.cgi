#!/usr/bin/perl

use MinorImpact;

use note;

my $MI = new MinorImpact({ https => 1, config_file => "../conf/minorimpact.conf" });
$MI->cgi({ actions => { archive => \&archive, edit => \&edit, index => \&index, note => \&note }, tag=>'new' });

sub archive {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");
    my $CGI = $MINORIMPACT->getCGI();

    my $object_id = $CGI->param('object_id') || $CGI->param('id') || $MINORIMPACT->redirect();
    my $collection_id = $CGI->param('collection_id') || $CGI->param('cid');

    my $object = new MinorImpact::Object($object_id) || $MINORIMPACT->redirect();

    my @tags = grep { !/new/; } $object->getTags();
    #MinorImpact::log(8, "\@tags='" . join(",", @tags) . "'");
    $object->update({ tags => join(",", @tags) });

    $MINORIMPACT->redirect("?cid=$collection_id");
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

    my $collection_id = $CGI->param('cid');
    my $limit = $CGI->param('limit') || 30;
    my $page = $CGI->param('page') || 1;
    my $search = $CGI->param('search');
    my $type_id = MinorImpact::Object::typeID('note');

    my $local_params = {object_type_id=>$type_id, sort=>1, debug=> "note::index.cgi::index();", user => $user->id() };

    my @collections = $user->getCollections();
    my $collection = new MinorImpact::Object($collection_id) if ($collection_id);
    if ($collection) {
        $search = $collection->searchText();
    }
   
    if ($search) {
        $local_params->{search} = $search;
    } else {
        $local_params->{tag} = "new";
    }
    $local_params->{debug} .= "collection::searchParams();";
    $local_params->{user_id} = $user->id();
    $local_params->{page} = $page;
    $local_params->{limit} = $limit + 1;

    #my $max = scalar(MinorImpact::Object::Search::search({ %$local_params, id_only => 1 }));
    my @objects = MinorImpact::Object::Search::search($local_params);

    #my @tags;
    #my %tags;
    #foreach my $object (@objects) {
    #    map { $tags{$_}++; } $object->getTags();
    #}
    #@tags = reverse sort { $tags{$a} <=> $tags{$b}; } keys %tags;
    #splice(@tags, 5);

    my $url_last = $page>1?"$script_name?cid=$collection_id&page=" . ($page - 1):'';
    my $url_next = (scalar(@objects)>$limit)?"$script_name?cid=$collection_id&page=" . ($page + 1):'';
    pop(@objects) if ($url_next);
    #MinorImpact::CGI::index($MINORIMPACT);
    $TT->process('index', {
                            collections => [ @collections ],
                            objects     => [ @objects ],
                            search      => $search,
                            type_id     => $type_id,
                            type_name   => 'note',
                            url_last    => $url_last,
                            url_next    => $url_next,
                        }) || die $TT->error();
}

sub note {
    my $MINORIMPACT = shift || return;
    my $params = shift ||{};

    my $CGI = MinorImpact::getCGI();
    my $TT = MinorImpact::getTT();
    my $user = MinorImpact::getUser({ force => 1 });

    my $object_id = $CGI->param('id') || $MINORIMPACT->redirect();
    my $object = new MinorImpact::Object($object_id) || $MINORIMPACT->redirect();

    my @collections = $user->getCollections();

    $TT->process('note', {
                            collections => [ @collections ],
                            object      => $object,
                            type_name   => 'note',
                        }) || die $TT->error();
}
