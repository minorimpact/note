package project;

use Data::Dumper;
use Text::Markdown 'markdown';
use Time::Local;

use MinorImpact;
use MinorImpact::Object;
use MinorImpact::User;
use MinorImpact::Util;

our @ISA = qw(MinorImpact::Object);

sub new {
    my $package = shift;
    my $params = shift;
    #MinorImpact::log(7, "starting");

    my $self = $package->SUPER::_new($params);
    bless($self, $package);

    #$self->log(7, "ending");
    return $self;
}

sub back {
    return MinorImpact::url( { action=>'projects' });
}

our $VERSION = 7;
sub dbConfig {
    #MinorImpact::log(7, "starting");

    # Verify type exists.
    my $project_type_id = MinorImpact::Object::Type::add({ name => 'project', public => 0, readonly => 0 });
    die "Could not add project type\n" unless ($project_type_id);

    MinorImpact::Object::Type::addField({ object_type_id => 'MinorImpact::settings', name => 'default_tag', type => 'string', default_value => 'new', required => 1});
    MinorImpact::Object::Type::addField({ object_type_id => 'MinorImpact::settings', name => 'results_per_page', type => 'int', default_value => '50', required => 1});

    # Bootstrap additional types.
    MinorImpact::Object::Type::add({ name => 'person', public => 0, readonly => 0 });
    person::dbConfig();
    MinorImpact::Object::Type::add({ name => 'location', public => 0, readonly => 0 });
    location::dbConfig();

    MinorImpact::Object::Type::setVersion($project_type_id, $VERSION);
    #MinorImpact::log(7, "ending");
    return;
}

sub get {
    my $self = shift || return;
    my $field = shift || return;

    if ($field eq 'project_id') {
        return $self->id();
    }
    return $self->SUPER::get($field);
}


