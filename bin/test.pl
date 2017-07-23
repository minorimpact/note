#!/usr/bin/perl

use Time::HiRes qw(tv_interval gettimeofday);

use MinorImpact;
use MinorImpact::InfluxDB;
use MinorImpact::Object;
use MinorImpact::Object::Search;
use MinorImpact::Util;

use lib "../lib";
use note;

my $test_count = 10;
my $MAX_CHILD_COUNT = 3;
my $verbose = 0;
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
my $avg_time = $total_time/$test_count;
#print "total_time=$total_time\n";
#print "avg_time=$avg_time\n";
MinorImpact::InfluxDB::influxdb({ db => "note_stats", metric => "test_avg", value => $avg_time });

my $MINORIMPACT = new MinorImpact({ config_file => "/usr/local/www/note.minorimpact.com/conf/minorimpact.conf", no_log => 1 });
my $DB = $MinorImpact::SELF->{DB};
my $USERDB = $MinorImpact::SELF->{USERDB};
my $user_count = $USERDB->selectrow_array("SELECT count(*) FROM user");
my $note_count = $DB->selectrow_array("SELECT count(*) FROM object WHERE object_type_id=?", undef, (MinorImpact::Object::typeID('note')));
print "user_count=$user_count\n" if ($verbose);
MinorImpact::InfluxDB::influxdb({ db => "note_stats", metric => "user_count", value => $user_count });
print "note_count=$note_count\n" if ($verbose);
MinorImpact::InfluxDB::influxdb({ db => "note_stats", metric => "note_count", value => $note_count });

sub test {
    my $test_start_time = [gettimeofday];
    my $MINORIMPACT = new MinorImpact({ config_file => "/usr/local/www/note.minorimpact.com/conf/minorimpact.conf", no_log => 1 });
    my $password = time() . $$ . int(rand(100)) ;
    my $username = "test_user_note_$password";
    #print "adding test_user $username\n";
    MinorImpact::User::addUser({ username => $username, password => $password });
    my $user = MinorImpact::getUser({ username => $username, password => $password }) || die "Can't retrieve user $username\n";;

#print "user name: " . $user->name() . "\n";
#print "user id: " . $user->id() . "\n";

    my $tag = randomText(1);
    my $note_count = 5; #int(rand(5)) + 1;
#print "creating $note_count notes\n";
    for (my $i = 0; $i < $note_count; $i++) {
        my $text = randomText() . '.';
        my $note = new note({ detail => $text, user_id => $user->id(), tags=>$tag });
        if ($text ne $note->get('detail')) {
#print "text mismatch\n";
        }
    }

    #Search for all added notes.
    my @notes = MinorImpact::Object::Search::search({ query => { 
                                                        object_type_id => MinorImpact::Object::typeID('note'), 
                                                        user_id => $user->id(),
                                                    } });
    if (scalar(@notes) != $note_count) {
        #print "note count mismatch: '$note_count' != '" . scalar(@notes) . "'\n";
    }

    # Tag search
    @notes = MinorImpact::Object::Search::search({ query => { 
                                                        object_type_id => MinorImpact::Object::typeID('note'), 
                                                        search => "tag:$tag",
                                                        user_id => $user->id(),
                                                    } });
    if (scalar(@notes) != $note_count) {
        #print "note count mismatch: '$note_count' != '" . scalar(@notes) . "'\n";
    }
    my $test_end_time = [gettimeofday];
    #print "test_time=" . tv_interval($test_start_time, $test_end_time) . "\n";
    #print "deleting user $username\n";
    #$user->delete();
}

