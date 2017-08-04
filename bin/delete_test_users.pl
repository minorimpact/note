#!/usr/bin/perl


use MinorImpact;
use MinorImpact::Object;
use MinorImpact::Object::Search;
use MinorImpact::Util;

use lib "../lib";
use note;

my $MINORIMPACT = new MinorImpact();

my $DB = $MinorImpact::SELF->{DB};
my $USERDB = $MinorImpact::SELF->{USERDB};

# Delete the users with the automated "test_user_*" name.
my $users = $USERDB->selectall_arrayref("SELECT id, name FROM user WHERE name LIKE 'test_user_%' ORDER BY RAND() LIMIT 500", {Slice=>{}});
foreach my $row (@$users) {
    next if ($row->{id} == 1);
    print $row->{id} . ": " . $row->{name} . "\n";
    my $username = $row->{name};
    my ($password) = $username =~/_([0-9]+)$/;
    my $user = MinorImpact::user({ username => $username, password => $password });
    $user->delete({ username => $username, password => $password }) if ($user);
}
