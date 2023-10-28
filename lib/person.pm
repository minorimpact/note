package person;

use Data::Dumper;
use Text::Markdown 'markdown';
use Time::Local;

use MinorImpact;
use MinorImpact::Object;
use MinorImpact::User;
use MinorImpact::Util;

#use projectMaster;

#our @ISA = qw(projectMaster);
our @ISA = qw(MinorImpact::Object);


sub new {
    my $package = shift;
    my $params = shift;
    #MinorImpact::log(7, "starting");

    if ($params->{first_name} && $params->{last_name}) {
        $params->{name} = $params->{last_name} . ", " . $params->{first_name};
    } elsif ($params->{last_name}) {
        $params->{name} = $params->{last_name};
    } elsif ($params->{first_name}) {
        $params->{name} = $params->{first_name};
    }

    my $self = $package->SUPER::_new($params);
    bless($self, $package);

    #$self->log(7, "ending");
    return $self;
}

sub cmp {
    my $self = shift || return;
    my $b = shift;

    my $compare_string = $self->name();
    $compare_string =~s/^van //i;
    $compare_string =~s/^von //i;
    $compare_string =~s/^the //i;
    if ($b) {
        return ($compare_string cmp $b->cmp());
    } 
    return $compare_string;
}

our $VERSION = 1;
sub dbConfig {
    MinorImpact::log('debug', "starting");

    # Verify type exists.
    my $object_type = new MinorImpact::Object::Type({ name => 'person', plural => 'people', no_name=> 1, public => 0 });
    die "Could not add object_type record\n" unless ($object_type);

    $object_type->addField({ name => 'birthday',   type => 'datetime', });
    $object_type->addField({ name => 'detail',     type => 'text', });
    $object_type->addField({ name => 'first_name', type => 'string', description => 'Given name' });
    $object_type->addField({ name => 'last_name',  type => 'string', description => 'Family name' });
    $object_type->addField({ name => 'nickname',   type => '@string', });
    $object_type->addField({ name => 'project_id', type => 'project', required => 1});

    $object_type->setVersion($VERSION);

    MinorImpact::log('debug', "ending");
    return;
}

sub form {
    my $self = shift || {};
    my $params = shift || {};

    my $form;
    my $date_select;

    if (ref($self) eq "HASH") {
        $params = $self;
        undef ($self);
    } elsif ($self eq 'event') {
        undef($self);
    }

    my $local_params = cloneHash($params);
    $local_params->{no_name} = 1;
    if ($self) {
        $form = $self->SUPER::form($local_params);
    } else {
        $local_params->{object_type_id} = MinorImpact::Object::typeID(__PACKAGE__);
        $form = MinorImpact::Object::form($local_params);
    }
    return $form;
}

sub name {
    my $self = shift || return;
    my $params = shift || {};

    my $first = $self->get('first_name');
    my $last = $self->get('last_name');
    if ($params->{format} eq 'title') {
        return "$first $last" if ($first && $last);
    }
    return "$last, $first" if ($first && $last);

    return $last || $first if ($last || $first);
    return $self->SUPER::name($params);
}

my $COMMENT =<<COMMENT;
sub narrative {
    my $self = shift || return;
    my $params = shift || {};

    my $local_params = cloneHash($params);
    $local_params->{sort} = 1;
    $local_params->{object_type_id} = MinorImpact::Object::typeID('events');
    my @events = $self->getChildren($local_params);

    my @narrative;
    foreach my $event (@events) {
        my $detail = $event->get('detail', {format=>'text'});
        if ($detail) {
            foreach my $person ($event->getPeople()) {
                $detail = $person->personify({text=>$detail});
            }
            my $location = $event->getLocation();
            $detail = $location->locatify({text=>$detail}) if ($location);

            my $narrative->{text} = markdown($detail);
            $narrative->{event} = $event->toString({format=>'small'});
            push(@narrative, $narrative);
        }
    }
    return @narrative;
}

sub personify {
    my $self = shift || return;
    my $params = shift || return;

    my $text = $params->{text} || return;

    my @test_strings = ();
    my $first = $self->get('first_name');
    my $last = $self->get('last_name');
    my @nicknames = $self->get('nickname');

    push(@test_strings, "$first $last") if ($first && $last);
    push(@test_strings, $first) if ($first);
    push(@test_strings, $last) if ($last);
    push(@test_strings, @nicknames) if (scalar(@nicknames));

    my $script_name = MinorImpact::scriptName();
    my $url = "$script_name?id=" . $self->id();
    foreach my $test (@test_strings) {
        if ($text =~/\W($test(['s]*)?)\W/i) {
            my $replace = $1;
            $text =~s/$replace/\[$replace\]\($url\)/;
            last;
        }
    }

    return $text;
}
COMMENT

sub toString {
    my $self = shift || return;
    my $params = shift || {};

    if ($params->{format} eq 'title') {
        my $first = $self->get('first_name');
        my $last = $self->get('last_name');

        my $name = $first || $last;
        $name = "$first $last" if ($first && $last);

        return "<a href a='" . MinorImpact::url({ action => 'object', object_id => $self->id() }) . "'>$name</a>";
    } else {
        return $self->SUPER::toString($params);
    }
}

# Override the default update to properly munge the first and last names into a 
#   properly formatted name for the object. 
sub update {
    my $self = shift || return;
    my $params = shift || {};

    my $local_params = cloneHash($params);
    if ($local_params->{first_name} && $local_params->{last_name}) {
        $local_params->{name} = $local_params->{last_name} . ", " . $local_params->{first_name};
    } elsif ($local_params->{last_name}) {
        $local_params->{name} = $local_params->{last_name};
    }
    $self->SUPER::update($local_params);
}

1;
