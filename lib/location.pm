package location;

use Data::Dumper;
use Text::Markdown 'markdown';
use Time::Local;
use URI::Escape;

use MinorImpact;
use MinorImpact::Object;
use MinorImpact::Util;

#use projectMaster;

our @ISA = qw(MinorImpact::Object);

sub new {
    my $package = shift;
    my $params = shift;
    #MinorImpact::log(7, "starting");

    my $self = $package->SUPER::_new($params);
    bless($self, $package);

    #$self->log(7, "ending");
    return $self;
}

our $VERSION = 2;
sub dbConfig {
    #MinorImpact::log(7, "starting");

    # Verify type exists.
    my $object_type_id = MinorImpact::Object::Type::add({ name => 'location', public => 1 });
    die "Could not add object_type record\n" unless ($object_type_id);

    MinorImpact::Object::Type::addField({ object_type_id => $object_type_id, name => 'address',    type => 'string', });
    MinorImpact::Object::Type::addField({ object_type_id => $object_type_id, name => 'detail',     type => 'text', });
    MinorImpact::Object::Type::addField({ object_type_id => $object_type_id, name => 'lat',        type => 'float', });
    MinorImpact::Object::Type::addField({ object_type_id => $object_type_id, name => 'lon',        type => 'float', });
    MinorImpact::Object::Type::addField({ object_type_id => $object_type_id, name => 'project_id', type => 'project', required => 1});

    MinorImpact::Object::Type::setVersion($object_type_id, $VERSION);

    #MinorImpact::log(7, "ending");
    return;
}

sub form {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");
    if ($self eq 'location') {
        undef($self);
    } elsif(ref($self) eq 'HASH') {
        $params = $self;
        undef($self);
    }
    my $local_params = cloneHash($params);
    $local_params->{edit} = 1;

    my $super_string;
    if ($self) {
        $super_string = $self->SUPER::form($local_params);
    } else {
        $super_string = MinorImpact::Object::form($local_params);
    }
    $local_params->{google_map_key} = 'AIzaSyAbBJbTvC0xXtzzHYuTN7Bspu93ECbR8EE';
    my $string;
    $string .= "<table><tr><td>$super_string</td><td><div id='map'></div></td></tr></table>\n";
    if ($self) {
        $string .= $self->map($local_params);
    } else {
        $string .= location::map($local_params);
    }
    #MinorImpact::log(7, "ending");
    return $string;
}

sub toString {
    my $self = shift || return;
    my $params = shift || {};

    my $local_params = cloneHash($params);
    $local_params->{google_map_key} = 'AIzaSyAbBJbTvC0xXtzzHYuTN7Bspu93ECbR8EE';
    my $string = $self->SUPER::toString($local_params);

    if ($local_params->{detail} || $local_params->{format} eq 'column') {
        $string = "<table><tr><td>$string</td><td>Map:<div id='map'></div></td></tr></table>\n";
        $string .= $self->map($local_params);
    }
    return $string;
}

sub map {
    my $self = shift || return;
    my $params = shift || {};

    if (ref($self) eq 'HASH') {
        $params = $self;
        undef($self);
    }

    my $lat = ($self?$self->get('lat'):'') || "38.68";
    my $lon = ($self?$self->get('lon'):'') || "-98.21";
    my $name = ($self?$self->name():$params->{name}) || '';
    $name =~s/'/\\'/g;
    my $map_opts = "center: {lat: $lat, lng: $lon}, zoom: 8, tilt: 0";
    unless ($params->{edit}) {
        $map_opts .= ", draggable: false, streetViewControl: false, scrollwheel: false";
    }
    my $map = <<SCRIPT;
<script>
    var map; 
    var markerl
    function initMap() { 
        map = new google.maps.Map(document.getElementById('map'), { $map_opts }); 
        marker = new google.maps.Marker({
            position: {lat: $lat, lng: $lon},
            map: map,
            title: '$name'
        });
SCRIPT
    if ($params->{edit}) {
        $map .= <<SCRIPT;
            google.maps.event.addListener(map, "rightclick", function(event) {
                var lat = event.latLng.lat();
                var lng = event.latLng.lng();
                \$("#lat").val(lat);
                \$("#lon").val(lng);
                marker.setMap(null);
                marker = new google.maps.Marker({
                    position: {lat: lat, lng: lng},
                    map: map,
                    title: '$name'
                });
            });
SCRIPT
    }
    $map .= <<SCRIPT;
    }
</script> 
<script src='https://maps.googleapis.com/maps/api/js?key=$params->{google_map_key}&callback=initMap' async defer></script>
SCRIPT
    return $map;
}


my $COMMENT = q(
sub narrative {
    my $self = shift || return;
    my $params = shift || {};
    
    my $local_params = cloneHash($params);
    $local_params->{sort} = 1;
    $local_params->{object_type_id} = MinorImpact::Object::typeID('events');
    my @events = $self->getChildren($local_params);
    
    my @narrative;
    foreach my $event (@events) {
        my $detail = $event->get('detail', {format=>'text'});
        if ($detail) { 
            foreach my $person ($event->getPeople()) {
                $detail = $person->personify({text=>$detail});
            }
            foreach my $location ($event->getLocation()) {
                $detail = $location->locatify({text=>$detail});
            }
            
            my $narrative->{text} = markdown($detail);
            $narrative->{event} = $event->toString({format=>'small'});
            push(@narrative, $narrative);
        }
    }
    return @narrative;
}

sub locatify {
    my $self = shift || return;
    my $params = shift || return;

    #MinorImpact::log(7, "starting(" . $self->id() . ")");

    my $text = $params->{text} || return;

    my @test_strings = ();
    my $name = $self->name();

    push(@test_strings, $name) if ($name);

    my $script_name = MinorImpact::scriptName();
    my $url = "$script_name?id=" . $self->id();
    foreach my $test (@test_strings) {
        if ($text =~/\W($test(['s]*)?)\W/i) {
            my $replace = $1;
            $text =~s/$replace/\[$replace\]\($url\)/;
            last;
        }
    }

    return $text;
});

1;

