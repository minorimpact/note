package bookmark;

use Data::Dumper;
use HTML::FormatText;
use HTTP::Request;
use LWP::UserAgent;
use Time::Local;
use URI::Escape;

use MinorImpact;
use MinorImpact::FormatMarkdown;
use MinorImpact::Object;
use MinorImpact::Util;

our @ISA = qw(MinorImpact::Object);

sub new {
    my $package = shift;
    my $params = shift;
    #MinorImpact::log(7, "starting");

    if ($params->{url} && !$params->{name}) {
        $params->{name} = $params->{url};
    }
    my $self = $package->SUPER::_new($params);
    bless($self, $package);

    if (ref($params) eq "HASH" && !$self->get('raw_html')) {
        my $request = HTTP::Request->new(GET => $self->get('url'));
        my $ua = LWP::UserAgent->new;
        my $response = $ua->request($request);
        my $content = $response->content;
        my ($title) = $content =~/<title>([^<]+)<\/title>/;
        
        my $parse_text = parse($content);
        my $values = {raw_html=>$content, parse_text=>$parse_text, parse_version=>$PARSE_VERSION, parse_date=>toMysqlDate()};
        $values->{name} = $title if ($title);
        $self->update($values);
    }

    #$self->log(7, "ending");
    return $self;
}

our $VERSION = 2;
sub dbConfig {
    MinorImpact::log(7, "starting");

    # Verify type exists.
    my $object_type_id = MinorImpact::Object::Type::add({ name => 'bookmark', });
    die "Could not add object_type record\n" unless ($object_type_id);

    MinorImpact::Object::Type::addField({ object_type_id => $object_type_id, name => 'parse_date', type => 'datetime', readonly => 1,});
    MinorImpact::Object::Type::addField({ object_type_id => $object_type_id, name => 'parse_text', type => 'text', readonly => 1,});
    MinorImpact::Object::Type::addField({ object_type_id => $object_type_id, name => 'parse_version', type => 'string', readonly => 1,});
    MinorImpact::Object::Type::addField({ object_type_id => $object_type_id, name => 'raw_html', type => 'text', hidden => 1, readonly => 1, });
    MinorImpact::Object::Type::addField({ object_type_id => $object_type_id, name => 'url', type => 'url', required => 1, });
    MinorImpact::Object::Type::addField({ object_type_id => $object_type_id, name => 'project_id', type => 'project', required => 1, });

    MinorImpact::Object::Type::setVersion($object_type_id, $VERSION);

    MinorImpact::log(7, "ending");
    return;
}

our $PARSE_VERSION = 14;
sub parse {
    my $html = shift || return;

    #my $text = MinorImpact::FormatMarkdown->format_string($html);
    my $text = HTML::FormatText->format_string($html);
    #$text =~s/\n\n/__FUCK_FUCKENSTEIN_FUCKSICLE__/gm;
    #$text =~s/\n\s+/ /g;
    #$text =~s/__FUCK_FUCKENSTEIN_FUCKSICLE__/\n\n/gm;
    return $text;
}

#sub form {
#    my $self = shift || return;
#    my $params = shift || {};
#
#    my $local_params = cloneHash($params);
#    my $form = $self->SUPER::form($local_params);
#    return $string;
#}

sub toString {
    my $self = shift || return;
    my $params = shift || {};

    my $local_params = cloneHash($params);
    my $string = $self->SUPER::toString($local_params);
    #my $tt = new MinorImpact()->templateToolkit();
    #if ($local_params->{column}) {
    #    $tt->process('bookmark_column', {bookmark=>$self}, \$string) || die $tt->error();
    #} else {
    #    $tt->process('bookmark', {bookmark=>$self}, \$string);
    #}

    return $string;
}

1;

