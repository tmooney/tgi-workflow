#!/gsc/bin/perl

use strict;
use warnings;

use above 'Cord';
use Cord::Simple;

UR::ModuleBase->message_callback(
    'debug',
    sub {
        my $error = shift;
        my $self = shift;

        print $self->class . ' ' . $error->string if $self->isa('Cord::Executor');
    }
);

$Cord::Simple::start_servers = 0;
$Cord::Simple::store_db = 1;

my $output = run_workflow_lsf(
    \*DATA, 
    'model input string' => 'foo bar baz',
    'sleep time' => 90 
);

print Data::Dumper->new([$output,\@Cord::Simple::ERROR])->Dump;

__DATA__
<?xml version='1.0' standalone='yes'?>
<workflow name="Example Cord" executor="Cord::Executor::SerialDeferred">
  <link fromOperation="input connector" fromProperty="sleep time" toOperation="sleep" toProperty="seconds" />
  <link fromOperation="echo" fromProperty="result" toOperation="wait for sleep and echo" toProperty="echo result" />
  <link fromOperation="wait for sleep and echo" fromProperty="echo result" toOperation="output connector" toProperty="result" />
  <link fromOperation="echo" fromProperty="output" toOperation="output connector" toProperty="model output string" />
  <link fromOperation="sleep" fromProperty="result" toOperation="wait for sleep and echo" toProperty="sleep result" />
  <link fromOperation="input connector" fromProperty="model input string" toOperation="echo" toProperty="input" />
  <link fromOperation="time" fromProperty="today" toOperation="output connector" toProperty="today" />
  <operation name="wait for sleep and echo">
    <operationtype typeClass="Cord::OperationType::Block">
      <property>echo result</property>
      <property>sleep result</property>
    </operationtype>
  </operation>
  <operation name="sleep">
    <operationtype commandClass="Cord::Test::Command::Sleep" typeClass="Cord::OperationType::Command" />
  </operation>
  <operation name="echo">
    <operationtype commandClass="Cord::Test::Command::Echo" typeClass="Cord::OperationType::Command" />
  </operation>
  <operation name="time">
    <operationtype commandClass="Cord::Test::Command::Time" typeClass="Cord::OperationType::Command" />
  </operation>
  <operationtype typeClass="Cord::OperationType::Model">
    <inputproperty>model input string</inputproperty>
    <inputproperty>sleep time</inputproperty>
    <outputproperty>model output string</outputproperty>
    <outputproperty>result</outputproperty>
    <outputproperty>today</outputproperty>
  </operationtype>
</workflow>
