#!/usr/bin/perl


use MinorImpact;
use MinorImpact::Object;
use MinorImpact::Object::Search;
use MinorImpact::Util;

use lib "../lib";
use note;

my $MINORIMPACT = new MinorImpact({ config_file => "../conf/minorimpact.conf" });

my $DB = $MinorImpact::SELF->{DB};
my $USERDB = $MinorImpact::SELF->{USERDB};

# Delete the users with the automated "test_user_*" name.
my $users = $USERDB->selectall_arrayref("SELECT id, name FROM user WHERE name LIKE 'test_user_note_%'", {Slice=>{}});
foreach my $row (@$users) {
    next if ($row->{id} == 1);
    print $row->{id} . ": " . $row->{name} . "\n";
    my $username = $row->{name};
    my ($password) = $username =~/_([0-9]+)$/;
    my $user = MinorImpact::getUser({ username => $username, password => $password });
    $user->delete({ username => $username, password => $password }) if ($user);
}

# Look for orphaned objects that have no owner, and delete them.  This is an issue
#   that should have been fixed, but leaving here just in case.
my $objects = $DB->selectall_arrayref("SELECT * FROM object", {Slice=>{}});
foreach my $row (@$objects) {
    next if ($row->{user_id} == 1);
    my $user;
    eval {
        $user = new MinorImpact::User($row->{user_id});
    };
    if (!$user) {
        print "deleting object '" . $row->{name} . "': user " . $row->{user_id} . " doesn't seem to exist\n";
        my $object_id = $row->{id};
        my $data = $DB->selectall_arrayref("select * from object_field where type like '%object[" . $row->{object_type_id} . "]'", {Slice=>{}});
        foreach my $r (@$data) {
            $DB->do("DELETE FROM object_data WHERE object_field_id=? and value=?", undef, ($r->{id}, $object_id));
        }

        my $data = $DB->selectall_arrayref("select * from object_text where object_id=?", {Slice=>{}}, ($object_id));
        foreach my $r (@$data) {
            $DB->do("DELETE FROM object_reference WHERE object_text_id=?", undef, ($r->{id}));
        }

        $DB->do("DELETE FROM object_data WHERE object_id=?", undef, ($object_id));
        $DB->do("DELETE FROM object_text WHERE object_id=?", undef, ($object_id));
        $DB->do("DELETE FROM object_reference WHERE object_id=?", undef, ($object_id));
        $DB->do("DELETE FROM object_tag WHERE object_id=?", undef, ($object_id));
        $DB->do("DELETE FROM object WHERE id=?", undef, ($object_id));
    }
}

