#!/usr/bin/perl

use Time::HiRes qw(tv_interval gettimeofday);
use Getopt::Long "HelpMessage";

my $options = {
                config => $ENV{MINORIMPACT_CONFIG},
                help => sub { HelpMessage(); },
            };

Getopt::Long::Configure("bundling");
GetOptions( $options,
            "config|c=s",
            "count|c=i",
            "force|f",
            "help|?|h",
            "id|i=i",
            "test_count|t=i",
            "verbose",
        ) || HelpMessage();


use MinorImpact;
use MinorImpact::Object;
use MinorImpact::Object::Search;
use MinorImpact::Test;
use MinorImpact::Util;


use Uravo::InfluxDB;

use lib "../lib";
use note;

die "config file $options->{config} does not exist" unless (-f $options->{config});
my $test_count = $options->{test_count} || $options->{count} || int(rand(10)) + 1;
my $MAX_CHILD_COUNT = 3;
my $verbose = $options->{verbose};
my $start_time = [gettimeofday];

my %child;
my $i = 0;
while ($i++ < $test_count) {
    my $pid;
    defined ($pid = fork()) || die "Can't fork\n";

    if ($pid) {
        $child{$pid} = 1;
        if (scalar keys %child >= $MAX_CHILD_COUNT) {
            my $done = wait();
            delete $child{$done};
        }
    } else {
        test();
        exit;
    }
}
while (wait() > 0) {}
my $end_time = [gettimeofday];
my $total_time = tv_interval($start_time, $end_time);
if ($test_count) {
    my $avg_time = $total_time/$test_count;
    print "average test time = $avg_time\n" if ($options->{verbose});
    Uravo::InfluxDB::influxdb({ db => "note_stats", metric => "test_avg", value => $avg_time });
}

my $MINORIMPACT = new MinorImpact({ no_log => 1 });
my $DB = $MinorImpact::SELF->{DB};
my $USERDB = $MinorImpact::SELF->{USERDB};
my $user_count = $USERDB->selectrow_array("SELECT count(*) FROM user");
my $note_count = $DB->selectrow_array("SELECT count(*) FROM object WHERE object_type_id=?", undef, (MinorImpact::Object::typeID('note')));
my $tag_count = $DB->selectrow_array("SELECT count(*) FROM object_tag");
my $unique_tag_count = $DB->selectrow_array("SELECT count(distinct(name)) FROM object_tag");

print "user_count = $user_count\n" if ($options->{verbose});
Uravo::InfluxDB::influxdb({ db => "note_stats", metric => "user_count", value => $user_count });
print "note_count = $note_count\n" if ($options->{verbose});
Uravo::InfluxDB::influxdb({ db => "note_stats", metric => "note_count", value => $note_count });
print "tag_count = $tag_count\n" if ($options->{verbose});
Uravo::InfluxDB::influxdb({ db => "note_stats", metric => "tag_count", value => $tag_count });
print "unique_tag_count = $unique_tag_count\n" if ($options->{verbose});
Uravo::InfluxDB::influxdb({ db => "note_stats", metric => "unique_tag_count", value => $unique_tag_count });
if ($user_count) {
    print "notes/user = " . ($note_count/$user_count) . "\n"  if ($options->{verbose});
    Uravo::InfluxDB::influxdb({ db => "note_stats", metric => "notes_per_user", value => ($note_count/$user_count) });
    print "tags/user = " . ($tag_count/$user_count) . "\n"  if ($options->{verbose});
    Uravo::InfluxDB::influxdb({ db => "note_stats", metric => "tags_per_user", value => ($tag_count/$user_count) });
}
if ($note_count) {
    print "tags/note = " . ($tag_count/$note_count) . "\n"  if ($options->{verbose});
    Uravo::InfluxDB::influxdb({ db => "note_stats", metric => "tags_per_note", value => ($tag_count/$note_count) });
}

sub test {
    my $test_start_time = [gettimeofday];
    srand();
    my $MINORIMPACT = new MinorImpact({ no_log => 1 });

    my $user = MinorImpact::Test::randomUser();
    my $user_type = int(rand(4));
    if ($user_type == 0 || !$user) { # new user
        my $password = time() . $$ . int(rand(100)) ;
        my $username = "test_user_note_$password";
        print "$$ adding user $username\n" if ($options->{verbose});
        MinorImpact::User::addUser({ username => $username, password => $password });
        $user = MinorImpact::user({ username => $username, password => $password }) || die "Can't retrieve user $username\n";;
    } elsif ($user_type == 1) { # angry user
        print "$$ deleting user " . $user->name() . "(" . $user->id() . ")\n" if ($options->{verbose});
        return $user->delete();
    } else {
        print "$$ logging in as " . $user->name() . "(" . $user->id() . ")\n" if ($options->{verbose});
    }

    my $DB = $MINORIMPACT->{DB};
    my @all_tags;
    my $all_tags = $DB->selectall_arrayref("SELECT distinct(name) FROM object_tag", {Slice=>{}});
    foreach my $tag (@$all_tags) {
        push(@all_tags, $tag->{name});
    }

    while (my $action_type = int(rand(6))) {
        my @notes = MinorImpact::Object::Search::search({ query => { 
                                                            object_type_id => MinorImpact::Object::typeID('note'), 
                                                            user_id => $user->id(),
                                                        } });
        my $note_count = scalar(@notes);
        my @user_tags;
        foreach my $note (@notes) {
            push(@user_tags, $note->tags());
        }
        if ($action_type == 1 || $note_count == 0) { # add note
            my $tag = tag(\@all_tags, \@user_tags);;

            my $text = ucfirst(randomText()) . '.';
            print "$$ adding note: $text tag: $tag\n" if ($options->{verbose});
            my $note = new note({ detail => $text, user_id => $user->id(), tags=>$tag });
            if ($text ne $note->get('detail')) {
                print "$$ ERROR: text mismatch\n" if ($options->{verbose});
            }
        } elsif ($action_type == 2) { # delete note
            my $note = $notes[int(rand($note_count))];
            $note->delete();
        } elsif ($action_type == 3) { # remove 'new' tag.
            my $note = $notes[int(rand($note_count))];

            if ($note->hasTag('new')) {
                print "$$ Removing 'new' tag from note\n" if ($options->{verbose});
                if (grep { /^new$/ } @tags) {
                    @tags = grep { !/^new$/; } $note->tags();
                }
                $note->update({ tags => join(",", @tags) });
                if ($note->hasTag('new')) {
                    print "$$ ERROR: Note still has 'new' tag\n" if ($options->{verbose});
                }
            }
        } else { # search by tag and edit
            my $tag = $user_tags[int(rand(scalar(@user_tags)))];
            print "$$ searching for tag:$tag\n" if ($options->{verbose});
            @notes = MinorImpact::Object::Search::search({ 
                query => { 
                object_type_id => MinorImpact::Object::typeID('note'), 
                search => "tag:$tag",
                user_id => $user->id(),
            } });
            if (scalar(@notes) == 0) {
                print "$$ ERROR: no notes returned for tag:$tag\n" if ($options->{verbose});
            } else {
                my $note = $notes[int(rand(scalar(@notes)))];
                my $text = ucfirst(randomText()) . '.';
                my $tag = tag(\@all_tags, \@user_tags);
                print "$$ updating note: $text tag:$tag\n" if ($options->{verbose});
                $note->update({detail => $text, tags=>$tag});
                if ($text ne $note->get('detail')) {
                    print "$$ ERROR: text mismatch\n" if ($options->{verbose});
                }
            }
        }
    }
    my $test_end_time = [gettimeofday];
    #print "test_time=" . tv_interval($test_start_time, $test_end_time) . "\n";
    #print "deleting user $username\n";
    #$user->delete();
}

sub tag {
    my $all_tags = shift || return;
    my $user_tags = shift || return;
    my $tag_count = shift || int(rand(3)) + 1;

    my $tags;
    for (my $i = 0; $i<$tag_count; $i++) {
        my $tag_type = int(rand(100));
        if ($tag_type < 5 || scalar(@{$all_tags}) == 0 ) {
            $tag = randomText(1);
            print "$$ creating a whole new tag: $tag\n" if ($options->{verbose});
        } elsif ($tag_type < 75 || scalar(@{$user_tags}) == 0 ) {
            $tag = $all_tags->[int(rand(scalar(@{$all_tags})))];
            print "$$ using an existing tag: $tag\n" if ($options->{verbose});
        } else {
            $tag = $user_tags->[int(rand(scalar(@{$user_tags})))];
            print "$$ reusing one of their own tags: $tag\n" if ($options->{verbose});
        }
        $tags .= "$tag,";
    }
    $tags =~s/,$//;
    return $tags;
}
