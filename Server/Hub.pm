
package Workflow::Server::Hub;

use strict;
use lib '/gscuser/eclark/lib';
use POE;
use POE::Component::IKC::Server;
use Workflow ();
use Sys::Hostname;

sub start {
    our $server = POE::Component::IKC::Server->spawn(
        port => 13424, name => 'Hub'
    );

    our $printer = POE::Session->create(
        inline_states => {
            _start => sub { 
                my ($kernel) = @_[KERNEL];
                $kernel->alias_set("printer");
                $kernel->call('IKC','publish','printer',[qw(stdout stderr)]);
            },
            stdout => sub {
                my ($arg) = @_[ARG0];
                
                print "$arg\n";
            },
            stderr => sub {
                my ($arg) = @_[ARG0];
                
                print STDERR "$arg\n";
            }
        }
    );
    
    our $dispatch = POE::Session->create(
        inline_states => {
            _start => sub { 
                my ($kernel, $heap) = @_[KERNEL, HEAP];
                $kernel->alias_set("dispatch");
                $kernel->call('IKC','publish','dispatch',[qw(add_work get_work end_work)]);

                $heap->{queue} = POE::Queue::Array->new();

                $kernel->post('IKC','monitor','*'=>{register=>'conn',unregister=>'disc'});
            },
            conn => sub {
                my ($name,$real) = @_[ARG1,ARG2];
                print " Remote ", ($real ? '' : 'alias '), "$name connected\n";
            },
            disc => sub {
                my ($name,$real) = @_[ARG1,ARG2];
                print " Remote ", ($real ? '' : 'alias '), "$name disconnected\n";
            },
            add_work => sub {
                my ($kernel, $heap, $arg) = @_[KERNEL, HEAP, ARG0];
                my ($instance, $type, $input) = @$arg;

                print "Add  Work: " . $instance->id . " " . $instance->name . "\n";

                $heap->{queue}->enqueue(100,[$instance,$type,$input]);

                my $cmd = $kernel->call($_[SESSION],'lsf_cmd');
                $kernel->post($_[SESSION],'system_cmd', $cmd);
            },
            get_work => sub {
                my ($kernel, $heap, $arg) = @_[KERNEL, HEAP, ARG0];
                my ($where) = @$arg;

                my ($priority, $queue_id, $payload) = $heap->{queue}->dequeue_next();
                if (defined $priority) {
                    my ($instance, $type, $input) = @$payload;
                    print 'Exec Work: ' . $instance->id . ' ' . $instance->name . "\n";

                    $kernel->post('IKC','post','poe://UR/workflow/begin_instance',[ $instance->id ]);
                    $kernel->post('IKC','post',$where, [$instance, $type, $input]);
                }
            },
            end_work => sub {
                my ($kernel, $heap, $arg) = @_[KERNEL, HEAP, ARG0];
                my ($id, $status, $output) = @$arg;

                $kernel->post('IKC','post','poe://UR/workflow/end_instance',[ $id, $status, $output ]);
            },
            lsf_cmd => sub {
                my ($kernel, $queue, $rusage) = @_[KERNEL, ARG0, ARG1];

                $queue ||= 'long';
                $rusage ||= ' -R "rusage[tmp=100]"';

                my $hostname = hostname;
                my $port = 13424;

                my $namespace = 'PAP';

                my $cmd = 'bsub -q ' . $queue . ' -N -u "' . $ENV{USER} . '@genome.wustl.edu" -m blades' . $rusage .
                    ' perl -e \'BEGIN { delete $ENV{PERL_USED_ABOVE}; } use above "' . $namespace . 
                    '"; use Workflow::Server::Worker; Workflow::Server::Worker->start("' . $hostname . '",' . $port . ')\'';

                return $cmd;
            },
            system_cmd => sub {
                my ($cmd) = @_[ARG0];
    
                system($cmd);
            }
        }
    );

    $Storable::forgive_me=1;

    POE::Kernel->run();
}

1;
