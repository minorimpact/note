package note;

use strict;

use Data::Dumper;
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

    if (ref($params) eq "HASH") {
        if (!$params->{name}) {
            $params->{name} = substr($params->{detail}, 0, 15) ."-". int(rand(10000) + 1);
        }

        my @tags;
        if ($params->{detail}) {
            my $detail = $params->{detail};

            # Pullinline tags and convert them to object tags.
            $detail =~s/\r\n/\n/g;
            @tags = extractTags(\$detail);
            $detail = trim($detail);

            # Change links to markdown formatted links.
            foreach my $url ($detail =~/(?<![\[\(])(https?:\/\/[^\s]+)/) {
                my $md_url = "[$url]($url)";
                $detail =~s/(?<![\[\(])$url/$md_url/;
            }
            $params->{detail} = $detail;
        }

        $params->{tags} .= " " . join(" ", @tags) . " new";
        #MinorImpact::log(8, "\$params->{tags}='" . $params->{tags} . "'");
    }
    my $self = $package->SUPER::_new($params);
    bless($self, $package);

    #MinorImpact::log(7, "ending");
    return $self;
}

sub form {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");
    if ($self eq 'note') {
        undef($self);
    } elsif(ref($self) eq 'HASH') {
        $params = $self;
        undef($self);
    }
    my $local_params = cloneHash($params);
    $local_params->{no_name} = 1;

    my $form;
    if ($self) {
        $form = $self->SUPER::form($local_params);
    } else {
        $form = MinorImpact::Object::form($local_params);
    }
    return $form;
}

sub name {
    my $self = shift || return;
    my $params = shift || {};

    my $local_params = cloneHash($params);
    $local_params->{one_line} = 1;
    $local_params->{truncate} = 120;
    return $self->get('detail', $local_params);
}

sub cmp {
    my $self = shift || return;
    my $b = shift;

    if ($b) {
        return ($self->get('mod_date') cmp $b->cmp());
    }

    return $self->get('mod_date');
}

our $VERSION = 5;
sub dbConfig {
    #MinorImpact::log(7, "starting");

    # Verify type exists.
    my $name = __PACKAGE__;
    my $object_type_id = MinorImpact::Object::Type::add({ name => $name, system => 0, });
    die "Could not add object_type record\n" unless ($object_type_id);

    MinorImpact::Object::Type::addField({ object_type_id => $object_type_id, name => 'detail', required => 1, type => 'text', });
    MinorImpact::Object::Type::addField({ object_type_id => $object_type_id, name => 'public', type => 'boolean', });

    MinorImpact::Object::Type::addField({ object_type_id => 'MinorImpact::settings', name => 'default_tag', type => 'string', default_value => 'new'});

    MinorImpact::Object::Type::setVersion($object_type_id, $VERSION);

    #MinorImpact::log(7, "ending");
    return;
}

1;
