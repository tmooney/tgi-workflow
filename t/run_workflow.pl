#!/gsc/bin/perl

use strict;
use warnings;

use above 'Workflow';
use Data::Dumper;

my $w = Workflow::Model->create_from_xml($ARGV[0] || 'sample.xml');

if (0) {
my $out = $w->execute(
    'model input string' => 'hello this is an echo test',
    'sleep time' => 3,
);

print Data::Dumper->new([$out])->Dump;
}
#print join("\n", map { $_->name } $w->operations_in_series) . "\n";

print join("\n", $w->validate) . "\n";

