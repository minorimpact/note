#!/usr/bin/perl

use Data::Dumper;
use Term::ReadKey;
use Getopt::Long "HelpMessage";

use MinorImpact;
use MinorImpact::Object;
use MinorImpact::Object::Search;

use lib "../lib";
use note;

my $MINORIMPACT;

my $config_file = "/etc/minorimpact/note-dev.minorimpact.com.conf";
my %options = (
                help => sub { HelpMessage(); },
                user => $ENV{USER},
            );

Getopt::Long::Configure("bundling");
GetOptions( \%options,
            "help|?|h",
            "password|p=s",
            "user|u=s",
            "verbose",
        ) || HelpMessage();


eval { main(); };
if ($@) {
    HelpMessage({message=>$@, exitval=>1});
}

sub main {
    my $username = $ENV{USER};
    my $password = $options{password};
    if (!$password) {
        print "password: ";
        ReadMode('noecho');
        $password = <STDIN>;
        chomp($password);
        print "\n";
        ReadMode('restore');
    }
    $MINORIMPACT = new MinorImpact({config_file=>$config_file});
    my $DB = MinorImpact::db() || die "Can't connect to database\n";
    my $user = $MINORIMPACT->user({username=>$username, password=>$password}) || die "Unable to validate user";
    die $user->name() . " does not have admin priviledges" unless ($user->isAdmin());

    my $type_id = MinorImpact::Object::type_id('note') || die "Can't get type_id for 'note'";

    print "         connected as: " . $user->name() . "\n";
    print "current parse version: $parse_version\n";
    print "         note type_id: $type_id\n";

    my @notes = MinorImpact::Object::Search::search({ query => {object_type_id=>$type_id, user_id=>$user->id() } });
    print "  # notes to scan: " . scalar(@notes) . "\n\n";
    foreach my $note (@notes) {
        print "setting project_id for " . $note->id() . ":" . $note->name() . ":\n";
        my $project_id = $note->get('project_id');
        print "project_id:$project_id\n";
        $note->update({ project_id=>1073590});
    }
}

1;
