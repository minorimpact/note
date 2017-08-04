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

# Look for orphaned objects that have no owner, and delete them.  This is an issue
#   that should have been fixed, but leaving here just in case.
print "looking for orphaned objects...\n";
my $objects = $DB->selectall_arrayref("SELECT * FROM object", {Slice=>{}});
foreach my $row (@$objects) {
    next if ($row->{user_id} == 1);
    my $user;
    eval {
        $user = new MinorImpact::User($row->{user_id});
    };
    if (!$user) {
        print "user " . $row->{user_id} . " doesn't exist\n";
        deleteObject($row->{id});
    }
}

print "looking for orphaned tags...\n";
my $tags = $DB->selectall_arrayref("SELECT DISTINCT(object_id) AS object_id FROM object_tag", {Slice=>{}});
foreach my $row (@$tags) {
    my $object_id = $row->{object_id};
    my $object;
    eval {
        $object = new MinorImpact::Object($object_id, { admin => 1 });
    };
    next if ($object);
    print "can't create object for id '$object_id'\n";
    deleteObject($object_id);
}

sub deleteObject {
    my $object_id = shift || return;

    print "deleting object '$object_id'\n";
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
    return;
}
