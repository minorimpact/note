#!/usr/bin/perl

use MinorImpact;
use MinorImpact::Util;

use location;
use note;
use person;
use project;

my $MI = new MinorImpact({ https => 1 });
$MI->www({ actions => { add => \&add, archive => \&archive, home => \&home, object => \&object, projects => \&projects, search => \&search } });

# override the default 'add' action to get the default project id and assign to the new object.
sub add {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");
    my $CGI = $MINORIMPACT->cgi();

    my $project_id = getProjectID();
    if ($project_id) {
        MinorImpact::log('debug', "Using project_id='$project_id'");
        $CGI->param('project_id', $project_id);
    }

    MinorImpact::WWW::add($MINORIMPACT, $params);
}

sub archive {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");
    my $CGI = $MINORIMPACT->cgi();

    my $collection_id = $CGI->param('collection_id') || $CGI->param('cid');
    my $object_id = $CGI->param('object_id') || $CGI->param('id') || $MINORIMPACT->redirect();
    my $search = $CGI->param('search');
    my $user = MinorImpact::user({ force => 1 });
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

sub getProjectID {
    my $user = MinorImpact::user({ force => 1 });
    my $project_id = MinorImpact::session('project_id');

    if (!$project_id) {
        MinorImpact::log('debug', "no project");
        if ($settings && $settings->get('default_project')) {
            #$local_params->{project_id} = $settings->get('default_project');
            $project_id = $settings->get('default_project');
        } else {
            MinorImpact::log('debug', "getting list of projects");
            my @projects = MinorImpact::Object::Search::search({ query => { object_type_id => 'project', user_id => $user->id(), id_only => 1}});
            MinorImpact::log('debug', scalar(@projects) . " objects");
            $project_id = @projects[0];
        } 
        MinorImpact::log('debug', "project_id='$project_id'");
        MinorImpact::session('project_id', $project_id);
    }

    return $project_id;
}

# override the home action to figure out the current default project id and modify the 
# query so it only pulls up objects that belong to that project.
sub home {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    #my $CGI = MinorImpact::cgi();
    #my $user = MinorImpact::user({ force => 1 });
    #my $object_type_id = MinorImpact::Object::typeID('note');

    my $local_params = cloneHash($params);
    #my $settings = $user->settings();

    my $project_id = getProjectID();
    if ($project_id) {
        $local_params->{query}{project_id} =  $project_id;
    }

    #my $search = MinorImpact::session('search');
    #my $collection_id = MinorImpact::session('collection_id');

    #if (!$search && !$collection_id) {
    #    $search = $default_search;
    #}
    #MinorImpact::session('search', $search);

    return MinorImpact::WWW::home($MINORIMPACT, $local_params);
}

# override the object action so that if the object we're looking at happens to be a 'project',
# we set the global session value to it's ID, so anything in the future that implicity references
# a project will use the last one we looked at.
sub object {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "starting");

    my $CGI = MinorImpact::cgi();
    my $object_id = $CGI->param('id');
    #MinorImpact::log('debug', "object_id='$object_id'");
    my $object = new MinorImpact::Object($object_id);
    if ($object) {
        my $object_type_name = $object->typeName();
        #MinorImpact::log('debug', "object_type_name='$object_type_name'");

        if ($object->typeName() eq 'project') {
            my $project_id = $object->id();
            #MinorImpact::log('debug', "object_id='$object_id'");
            MinorImpact::session('project_id', $object->id());
        }
    }

    return MinorImpact::WWW::object($MINORIMPACT, $params);
}

sub projects {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    my $CGI = MinorImpact::cgi();
    my $user = MinorImpact::user({ force => 1 });

    my @projects = $user->getObjects( { query => {  object_type_id => 'project' } });

    MinorImpact::tt('projects', {
        objects => [ @projects ],
        object_type_id => 'project',
    });
}

sub search {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};
    my $user = MinorImpact::user({ force => 1 });

    my $CGI = MinorImpact::cgi();
    my $local_params = cloneHash($params);

    # Get a list of projects to feed to the custom dropdown in the search_filter_site
    #   template.
    my @projects = $user->getObjects( { query => { object_type_id => 'project' } });
    $local_params->{tt_variables}{projects} = \@projects;

    $CGI->param('project_id', getProjectID()) unless ($CGI->param('project_id'));
    if ($CGI->param('project_id') eq 'All') {
        $CGI->param('project_id', undef);
    } elsif ($CGI->param('project_id')) {
        # Add application specific search criteria to the parameter object that gets
        #   sent to the the default search function.
        $local_params->{tt_variables}{project_id} = $CGI->param('project_id');
        $local_params->{query}->{project_id} = $CGI->param('project_id');
    }

    return MinorImpact::WWW::search($MINORIMPACT, $local_params);
}

