#!/usr/bin/env perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT}=1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS}=1;
}

use strict;
use warnings;

use Test::More tests => 6;
use above 'Cord';

my $dir = -d 't/xml.d' ? 't/xml.d' : 'xml.d';

require_ok('Cord::Model');
can_ok('Cord::Model',qw/create validate is_valid execute/);

my $w = Cord::Model->create_from_xml($dir . '/12_parallel.xml');
ok($w,'create workflow');
isa_ok($w,'Cord::Model');

ok(do {
    $w->validate;
    $w->is_valid;
},'validate');

my $data = $w->execute(
    input => {
        'test input' => [
            qw/ab cd ef gh jk/
        ]
    }
);

$w->wait;

my $output = $data->output;

$data->treeview_debug;

is_deeply(
    $output,
    {
        'test output' => [qw/ab cd ef gh jk/],
        'result' => [1,1,1,1,1]
    },
    'check output'
);
