#!/usr/bin/perl


use MinorImpact;
use MinorImpact::Object;
use MinorImpact::Object::Search;
use MinorImpact::Util;

use lib "../lib";
use note;

my $MINORIMPACT = new MinorImpact({ config_file => "../conf/minorimpact.conf" });

my $DB = $MinorImpact::SELF->{USERDB};
my $users = $DB->selectall_arrayref("SELECT id, name FROM user WHERE name LIKE 'test_user_note_%'", {Slice=>{}});
foreach my $row (@$users) {
    print $row->{id} . ": " . $row->{name} . "\n";
    my $user = new MinorImpact::User($row->{id}) || die "Can't create user " .$row->{name};
    $user->delete();
}
