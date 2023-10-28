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

our $VERSION = 12;
sub dbConfig {
    MinorImpact::debug(1);
    MinorImpact::log('debug', "starting");

    # Verify type exists.
    my $project_type = new MinorImpact::Object::Type({ name => 'project', public => 0, readonly => 0 });
    die "Could not add project type\n" unless ($project_type);

    $object_type->
    MinorImpact::addSetting({ name => 'default_tag', type => 'string', default_value => 'new', required => 1});
    MinorImpact::addSetting({ name => 'results_per_page', type => 'int', default_value => '50', required => 1});

    # Bootstrap additional types.
    my $object_type_id = MinorImpact::Object::typeID('bookmark');
    unless ($object_type_id) {
        new MinorImpact::Object::Type({ name => 'bookmark', public => 0, readonly => 0 });
        bookmark::dbConfig();
    }
    my $object_type_id = MinorImpact::Object::typeID('entry');
    unless ($object_type_id) {
        new MinorImpact::Object::Type({ name => 'entry', public => 0, readonly => 0 });
        entry::dbConfig();
    }
    my $object_type_id = MinorImpact::Object::typeID('location');
    unless ($object_type_id) {
        new MinorImpact::Object::Type({ name => 'location', public => 0, readonly => 0 });
        location::dbConfig();
    }
    my $object_type_id = MinorImpact::Object::typeID('person');
    unless ($object_type_id) {
        new MinorImpact::Object::Type({ name => 'person', public => 0, readonly => 0 });
        person::dbConfig();
    }
    my $object_type_id = MinorImpact::Object::typeID('thing');
    unless ($object_type_id) {
        new MinorImpact::Object::Type({ name => 'thing', public => 0, readonly => 0 });
        thing::dbConfig();
    }

    $project_type->setVersion($VERSION);
    MinorImpact::log('debug', "ending");
    MinorImpact::debug(0);
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


