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
            "count",
            "force|f",
            "help|?|h",
            "id|i=i",
            "test_count",
            "verbose",
        ) || HelpMessage();


use MinorImpact;
use MinorImpact::InfluxDB;
use MinorImpact::Object;
use MinorImpact::Object::Search;
use MinorImpact::Test;
use MinorImpact::Util;

use lib "../lib";
use note;

die "config file $options->{config} does not exist" unless (-f $options->{config});
my $test_count = $options->{test_count} || int(rand(10));
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
    MinorImpact::InfluxDB::influxdb({ db => "note_stats", metric => "test_avg", value => $avg_time });
}

my $MINORIMPACT = new MinorImpact({ no_log => 1 });
my $DB = $MinorImpact::SELF->{DB};
my $USERDB = $MinorImpact::SELF->{USERDB};
my $user_count = $USERDB->selectrow_array("SELECT count(*) FROM user");
my $note_count = $DB->selectrow_array("SELECT count(*) FROM object WHERE object_type_id=?", undef, (MinorImpact::Object::typeID('note')));
my $tag_count = $DB->selectrow_array("SELECT count(distinct(name)) FROM object_tag");
print "user_count=$user_count\n" if ($options->{verbose});
MinorImpact::InfluxDB::influxdb({ db => "note_stats", metric => "user_count", value => $user_count });
print "note_count=$note_count\n" if ($options->{verbose});
MinorImpact::InfluxDB::influxdb({ db => "note_stats", metric => "note_count", value => $note_count });
print "tag_count=$tag_count\n" if ($options->{verbose});
MinorImpact::InfluxDB::influxdb({ db => "note_stats", metric => "tag_count", value => $tag_count });

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
        $user = MinorImpact::getUser({ username => $username, password => $password }) || die "Can't retrieve user $username\n";;
    } elsif ($user_type == 1) { # angry user
        print "$$ deleting user " . $user->name() . "(" . $user->id() . ")\n" if ($options->{verbose});
        return $user->delete();
    } else {
        print "$$ logging in as " . $user->name() . "(" . $user->id() . ")\n" if ($options->{verbose});
    }

    while (my $action_type = int(rand(5))) {
        my @notes = MinorImpact::Object::Search::search({ query => { 
                                                            object_type_id => MinorImpact::Object::typeID('note'), 
                                                            user_id => $user->id(),
                                                        } });
        my @tags;
        my $note_count = scalar(@notes);
        my $tag_count = scalar(@tags);
        foreach my $note (@notes) {
            push(@tags, $note->tags());
        }
        if ($action_type == 1 || $note_count == 0) { # add note
            my $tag;
            if (int(rand(3)) == 1 || $tag_count == 0) {
                $tag = randomText(1);
            } else {
                $tag = $tags[int(rand($tag_count))];
            }
            my $text = randomText() . '.';
            print "$$ adding note: $text tag: $tag\n" if ($options->{verbose});
            my $note = new note({ detail => $text, user_id => $user->id(), tags=>$tag });
            if ($text ne $note->get('detail')) {
                print "$$ ERROR: text mismatch\n" if ($options->{verbose});
            }
        } elsif ($action_type == 2) { # delete note
            my $note = $notes[int(rand($note_count))];
            $note->delete();
        } else { # search by tag and edit
            my $tag = $tags[int(rand($tag_count))];
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
                my $text = randomText() . '.';
                print "$$ updating note: $text\n" if ($options->{verbose});
                $note->update({detail => $text});
                if ($text ne $note->get('detail')) {
                    print "$$ ERROR: text mismatch\n" if ($options->{verbse});
                }
            }
        }
    }
    my $test_end_time = [gettimeofday];
    #print "test_time=" . tv_interval($test_start_time, $test_end_time) . "\n";
    #print "deleting user $username\n";
    #$user->delete();
}

sub randomUser {
}
