package entry;

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
            $params->{name} = toMysqlDate();
            $params->{name} =~s/:[0-9][0-9]$//;
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

        my $user = MinorImpact::user({ force => 1 });
        my $settings = $user->settings();
        $params->{tags} .= " " . join(" ", @tags) . " " . $settings->get('default_tag');
        #MinorImpact::log(8, "\$params->{tags}='" . $params->{tags} . "'");
    }
    my $self = $package->SUPER::_new($params);
    bless($self, $package);

    #MinorImpact::log(7, "ending");
    return $self;
}

sub cmp {
    my $self = shift || return;
    my $b = shift;

    if ($b) {
        return ($self->get('publish_date') cmp $b->cmp());
    }

    return $self->get('publish_date');
}

our $VERSION = 2;
sub dbConfig {
    #MinorImpact::log(7, "starting");

    # Verify type exists.
    my $name = __PACKAGE__;
    my $object_type_id = MinorImpact::Object::Type::add({ name => $name, plural=>'entries', public=>1 });
    die "Could not add object_type record\n" unless ($object_type_id);

    MinorImpact::Object::Type::addField({ object_type_id => $object_type_id, name => 'content', required => 1, type => 'text', });
    MinorImpact::Object::Type::addField({ object_type_id => $object_type_id, name => 'publish_date', required => 1, type => 'datetime', });
    MinorImpact::Object::Type::addField({ object_type_id => $object_type_id, name => 'project_id', required => 1, type => 'project', });

    MinorImpact::Object::Type::setVersion($object_type_id, $VERSION);

    #MinorImpact::log(7, "ending");
    return;
}

1;
