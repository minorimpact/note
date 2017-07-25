package note;

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

#sub toString {
    #my $self = shift || return;
    #my $params = shift || {};
    #
#    if ($params->{format} eq 'default'
#}

1;
