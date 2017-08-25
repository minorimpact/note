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


sub churn {
    my $params = shift || return;

    #MinorImpact::log('debug', 'starting');
    use MinorImpact::Test;

    my $user = $params->{user} || return;
    my $verbose = $params->{verbose};
    my $settings = $user->settings();
    my $default_tag = $settings->get('default_tag');

    my $action_type = int(rand(6));
    while (my $action_type = int(rand(6))) {
        my @notes = $user->searchObjects({ query => { object_type_id => MinorImpact::Object::typeID(__PACKAGE__) }, } );

        my $note_count = scalar(@notes);
        my @user_tags;
        foreach my $note (@notes) {
            push(@user_tags, $note->tags());
        }
        if ($action_type == 1 || $note_count == 0) { # add note
            my $tag = tag(@user_tags);

            my $text = ucfirst(randomText()) . '.';
            print "$$ adding note: $text tag: $tag\n" if ($verbose);
            my $note = new note({ detail => $text, user_id => $user->id(), tags=>$tag });
            if ($text ne $note->get('detail')) {
                print "$$ ERROR: text mismatch\n" if ($verbose);
            }
        } elsif ($action_type == 2) { # delete note
            my $note = $notes[int(rand($note_count))];
            print "$$ deleting " . $note->name() . "\n" if ($verbose);
            $note->delete();
        } elsif ($action_type == 3) { # remove 'new' tag.
            my $note = $notes[int(rand($note_count))];

            if ($note->hasTag($default_tag)) {
                print "$$ Removing 'new' tag from note\n" if ($verbose);
                my @tags = grep { !/^$default_tag$/; } $note->tags();
                $note->update({ tags => join(",", @tags) });
                if ($note->hasTag($default_tag)) {
                    print "$$ ERROR: Note still has '$default_tag' tag\n" if ($verbose);
                }
            }
        } else { # search by tag and edit
            my $tag = $user_tags[int(rand(scalar(@user_tags)))];
            print "$$ searching for tag:$tag\n" if ($verbose);
            @notes = MinorImpact::Object::Search::search({ 
                query => { 
                object_type_id => MinorImpact::Object::typeID('note'), 
                search => "tag:$tag",
                user_id => $user->id(),
            } });
            if (scalar(@notes) == 0) {
                print "$$ ERROR: no notes returned for tag:$tag\n" if ($verbose);
            } else {
                my $note = $notes[int(rand(scalar(@notes)))];
                my $text = ucfirst(randomText()) . '.';
                my $tag = tag(@user_tags);
                print "$$ updating note: $text tag:$tag\n" if ($verbose);
                $note->update({detail => $text, tags=>$tag});
                if ($text ne $note->get('detail')) {
                    print "$$ ERROR: text mismatch\n" if ($verbose);
                }
            }
        }
    }
    #MinorImpact::log('debug', 'ending');
}

sub cmp {
    my $self = shift || return;
    my $b = shift;

    if ($b) {
        return ($self->get('mod_date') cmp $b->cmp());
    }

    return $self->get('mod_date');
}

our $VERSION = 9;
sub dbConfig {
    #MinorImpact::log(7, "starting");

    # Verify type exists.
    my $name = __PACKAGE__;
    my $object_type_id = MinorImpact::Object::Type::add({ name => $name, no_name => 1, public=>0, system => 0, });
    die "Could not add object_type record\n" unless ($object_type_id);

    MinorImpact::Object::Type::addField({ object_type_id => $object_type_id, name => 'detail', required => 1, type => 'text', });
    MinorImpact::Object::Type::delField({ object_type_id => $object_type_id, name => 'public', type => 'boolean', });

    MinorImpact::Object::Type::addField({ object_type_id => 'MinorImpact::settings', name => 'default_tag', type => 'string', default_value => 'new', required => 1});

    MinorImpact::Object::Type::setVersion($object_type_id, $VERSION);

    #MinorImpact::log(7, "ending");
    return;
}

sub name {
    my $self = shift || return;
    my $params = shift || {};
    #MinorImpact::log('debug', 'starting');

    my $local_params = cloneHash($params);
    $local_params->{one_line} = 1;
    $local_params->{truncate} = 120;
    return $self->get('detail', $local_params);
}

1;
