#!/usr/bin/env perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT}=1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS}=1;
}

use strict;
use warnings;

use Test::More tests => 25;
use Switch;

use above 'Workflow';

my @operationtypes = qw{
    Block Command Converge Dummy
    Model ModelInput ModelOutput
};

require_ok('Workflow');
require_ok('Workflow::OperationType');

foreach my $operationtype (@operationtypes) {
    my $operationtype_class = 'Workflow::OperationType::' . $operationtype;
    require_ok($operationtype_class);
    
    switch ($operationtype) {
        case 'Block' {
            my $props = [ qw{foo bar baz bzz} ];
            
            my $o;
            ok($o = $operationtype_class->create(
                properties => $props
            ),'create ' . $operationtype);
            
            my $vals = { foo => 1, bar => 'a', baz => '%', 'bzz' => 0 };
            my $out;
            ok($out = $o->execute(%$vals), 'execute ' . $operationtype);
            is_deeply($out,$vals,'check output ' . $operationtype);
        }
        case 'Command' {
            my $o = $operationtype_class->create(
                command_class_name => 'Workflow::Test::Command::Echo'
            );
            ok($o,'found ' . $operationtype);
            
            my $out;
            ok($out = $o->execute(
                input => 'Supercalifragilisticexpialidocious'
            ),'execute ' . $operationtype);
            
            is_deeply($out,{ 
                output => 'Supercalifragilisticexpialidocious',
                result => 1
            },'check output ' . $operationtype);
        }
        case 'Converge' {
            my $o;
            ok($o = $operationtype_class->create,'create ' . $operationtype);

            ok($o->input_properties([qw{ foo bar baz }]),'set input ' . $operationtype);
            ok($o->output_properties([qw{ bzz }]),'set output ' . $operationtype);

            my $out;
            ok($out = $o->execute(
                foo => [qw{a b c d e f}],
                bar => [qw{1 2 3 4 5 6}],
                baz => 'abcdef'
            ),'execute ' . $operationtype);

            is_deeply($out,{
                bzz => [qw{a b c d e f 1 2 3 4 5 6 abcdef}], result => 1
            },'check output ' . $operationtype);

            ok($out = $o->execute(
                foo => 'a',
                bar => 'b',
                baz => 'c'
            ), 'execute ' . $operationtype);
            is_deeply($out,{
                bzz => [qw{a b c}], result => 1
            },'check_output ' . $operationtype);
        }
        case 'Dummy' {
            my $o;
            ok($o = $operationtype_class->create(
                input_properties => [qw{ foo bar baz }],
                output_properties => [qw{ bzz bxy }]
            ),'create ' . $operationtype);
            
            my $out;
            ok($out = $o->execute(),'execute ' . $operationtype);
            
            is_deeply($out,{},'check output ' . $operationtype);
        }
        case 'Model' {
            if (0) {
            my $dir = -d 't/xml.d' ? 't/xml.d' : 'xml.d';
            my $w = Workflow::Model->create_from_xml($dir . '/00_basic.xml');
            
            my $o;
            ok($o = $w->operation_type,'found ' . $operationtype);
            
            my $out;
            ok($out = $o->execute(
                'model input string' => 'abracadabra',
                'sleep time' => 1
            ),'execute ' . $operationtype);

            is_deeply($out,{
                'model output string' => 'abracadabra',
                'today' => Workflow::Time->today,
                'result' => 1
            },'check output ' . $operationtype);
            }
        }
        case 'ModelInput' {
        }
        case 'ModelOutput' {
        }
    }
}

