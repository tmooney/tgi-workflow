#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 6;
use Devel::Size qw(size total_size);
use Workflow;

my $dir = -d 't/xml.d' ? 't/xml.d' : 'xml.d';

my $firstsize = total_size($UR::Object::all_objects_loaded->{'Workflow::Operation::Data'});

require_ok('Workflow::Model');

can_ok('Workflow::Model',qw/create validate is_valid execute/);

my $w = Workflow::Model->create_from_xml($dir . '/00_basic.xml');
ok($w,'create workflow');
isa_ok($w,'Workflow::Model');

ok(do {
    $w->validate;
    $w->is_valid;
},'validate');

foreach my $i (1..10) {

    my $collector = sub {
        my $data = shift;

        # just let it leave scope
    };

    $w->execute(
        input => {
            'model input string' => 'abracadabra321' . $i,
            'sleep time' => 1
        },
        output_cb => $collector
    );

    $w->wait;
    
}

my $size = total_size($UR::Object::all_objects_loaded->{'Workflow::Operation::Data'});

ok($size <= $firstsize, 'no cache growth');
