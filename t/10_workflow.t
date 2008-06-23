#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 25;
use Workflow;

require_ok('Workflow::Model');

can_ok('Workflow::Model',qw/create add_operation get_input_connector get_output_connector add_link validate is_valid execute/);

my $w = Workflow::Model->create(
    name => 'Example Workflow',
    input_properties => [ 'model input string', 'sleep time' ],
    output_properties => [ 'model output string', 'today', 'result' ],
);
ok($w,'create workflow');
isa_ok($w,'Workflow::Model');

my $echo = $w->add_operation(
    name => 'echo',
    operation_type => Workflow::Test::Command::Echo->operation
);
ok($echo,'add echo operation');
isa_ok($echo,'Workflow::Operation');

my $sleep = $w->add_operation(
    name => 'sleep',
    operation_type => Workflow::Test::Command::Sleep->operation
);
ok($sleep,'add sleep operation');

my $time = $w->add_operation(
    name => 'time',
    operation_type => Workflow::Test::Command::Time->operation
);
ok($time,'add time operation');
 
my $block = $w->add_operation(
    name => 'wait for sleep and echo',
    operation_type => Workflow::OperationType::Block->create(
        properties => ['echo result','sleep result']
    ),
);
ok($block,'add block operation');

my $modelin = $w->get_input_connector;
ok($modelin,'get input connector');
isa_ok($modelin,'Workflow::Operation');

my $modelout = $w->get_output_connector;
ok($modelout,'get output connector');
isa_ok($modelout,'Workflow::Operation');

my $link;

$link = $w->add_link(
    left_operation => $modelin,
    left_property => 'model input string',
    right_operation => $echo, 
    right_property => 'input',
);
ok($link,'link model input connector:model input string to echo:input');
isa_ok($link,'Workflow::Link');

$link = $w->add_link(
    left_operation => $modelin,
    left_property => 'sleep time',
    right_operation => $sleep,
    right_property => 'seconds',
);
ok($link,'link model input connector:sleep time to sleep:seconds');

$link = $w->add_link(
    left_operation => $echo,
    left_property => 'output',
    right_operation => $modelout,
    right_property => 'model output string',
);
ok($link,'link echo:output to model output connector:model output string');

$link = $w->add_link(
    left_operation => $sleep,
    left_property => 'result',
    right_operation => $block,
    right_property => 'sleep result',
);
ok($link,'link sleep:result to block:sleep result');

$link = $w->add_link(
    left_operation => $echo,
    left_property => 'result',
    right_operation => $block,
    right_property => 'echo result',
);
ok($link,'link echo:result to block:echo result');

$link = $w->add_link(
    left_operation => $block,
    left_property => 'echo result',
    right_operation => $modelout,
    right_property => 'result',
);
ok($link,'link block:echo result to model output connector:result');

$link = $w->add_link(
    left_operation => $time,
    left_property => 'today',
    right_operation => $modelout,
    right_property => 'today',
);
ok($link,'link time:today to model output connector:today');

ok(do {
    $w->validate;
    $w->is_valid;
},'validate');

my $output;
my $collector = sub {
    my $data = shift;
    $output = $data->output;
};

ok($w->execute(
    input => {
        'model input string' => 'abracadabra321',
        'sleep time' => 1
    },
    output_cb => $collector
),'execute workflow');

ok($w->wait,'wait for completion');

is_deeply(
    $output,
    {
        'model output string' => 'abracadabra321',
        'today' => UR::Time->today,
        'result' => 1
    },
    'check output'
);