package thing;

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
    MinorImpact::log('debug', "starting");

    my $self = $package->SUPER::_new($params);
    bless($self, $package);

    MinorImpact::log('debug', "ending");
    return $self;
}

sub cmp {
    my $self = shift || return;
    my $b = shift;

    my $compare_string = $self->name();
    $compare_string =~s/^the //i;
    $compare_string =~s/^a //i;
    if ($b) {
        return ($compare_string cmp $b->cmp());
    } 
    return $compare_string;
}

our $VERSION = 2;
sub dbConfig {
    MinorImpact::log('debug', "starting");

    # Verify type exists.
    my $object_type = new MinorImpact::Object::Type({ name => 'thing', public => 1 });
    die "Could not add object_type record\n" unless ($object_type);

    $object_type->addField({ name => 'detail', type => 'text', });
    $object_type->addField({ name => 'project_id', type => 'project', required => 1, });
    $object_type->addField({ name => 'location_id', type => 'location', required => 1, });

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
    #$local_params->{no_name} = 1;
    if ($self) {
        $form = $self->SUPER::form($local_params);
    } else {
        $local_params->{object_type_id} = MinorImpact::Object::type_id(__PACKAGE__);
        $form = MinorImpact::Object::form($local_params);
    }
    return $form;
}

1;
