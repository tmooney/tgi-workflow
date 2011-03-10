
package Cord::Model;

use strict;
use warnings;
use GraphViz;
use XML::Simple;
use File::Basename;

use Cord ();

class Cord::Model {
    isa => 'Cord::Operation',
    has => [
        operations => { is => 'Cord::Operation', is_many => 1, reverse_id_by => 'workflow_model' },
        links => { is => 'Cord::Link', is_many => 1 },
    ]
};

sub create {
    my $class = shift;
    my %params = @_;

    my $optype = $params{operation_type};
    unless ($params{operation_type}) {
        $optype = Cord::OperationType::Model->create(
            input_properties => delete($params{input_properties}) || [],
            output_properties => delete($params{output_properties}) || []
        );

        $params{operation_type} = $optype;
    }

    my $self = $class->SUPER::create(%params);

    $self->add_operation(
        name => 'input connector',
        operation_type => Cord::OperationType::ModelInput->create(
            input_properties => [],
            output_properties => $optype->input_properties
        ),
    );
    $self->add_operation(
        name => 'output connector',
        operation_type => Cord::OperationType::ModelOutput->create(
            input_properties => $optype->output_properties,
            output_properties => []
        ),
    );

    return $self;
}

sub XOXOXcreate_from_xml {
    my ($class, $filename) = @_;

    my $struct = XMLin($filename, KeyAttr=>[], ForceArray=>[qw/operation property inputproperty outputproperty link/]);
    my $self = $class->create_from_xml_simple_structure($struct,filename=>$filename);

    return $self;
}

sub save_to_xml {
    my $self = shift;
    my %args = @_;

    return XMLout($self->as_xml_simple_structure, RootName=>'workflow', XMLDecl=>1, %args);
}

sub create_from_xml_simple_structure {
    my $class = shift;
    my $struct = shift;
    my %params = (@_);

    my $self;
    if ($struct->{workflowFile}) {
        my $file_basepath = dirname($params{workflow_model}->filename);

        $self = $class->create_from_xml($file_basepath . '/' . $struct->{workflowFile});
        $self->name($struct->{name});
        $self->workflow_model($params{workflow_model});
    } else {
        my $operations = delete $struct->{operation};
        my $links = delete $struct->{link};

        if (my $par = delete $struct->{parallelBy}) {
            $params{parallel_by} = $par;
        }

        if (my $executor_class = delete $struct->{executor}) {
            $params{executor} = $executor_class->get();
        }

        $self = $class->SUPER::create_from_xml_simple_structure($struct,%params);

        foreach my $op_struct (@$operations) {
            my $op = Cord::Operation->create_from_xml_simple_structure($op_struct,workflow_model=>$self);
            if ($op->operation_type->isa('Cord::OperationType::Model')) {
                $op->executor($params{executor}) if ($params{executor});
            }
        }

        foreach my $link_struct (@$links) {
            my $link = Cord::Link->create_from_xml_simple_structure($link_struct,workflow_model=>$self);
        }
    }

    return $self;
}

sub as_xml_simple_structure {
    my $self = shift;

    my $struct = $self->SUPER::as_xml_simple_structure;

    $struct->{parallelBy} = $self->parallel_by if ($self->parallel_by);

    $struct->{operation} = [
        map {
            $_->as_xml_simple_structure
        } grep {
            $_->name ne 'input connector' && $_->name ne 'output connector'
        } $self->operations
    ];

    $struct->{link} = [
        map {
            $_->as_xml_simple_structure
        } $self->links
    ];

    return $struct;
}

sub get_input_connector {
    my $self = shift;

    my $input = Cord::Operation->get(
        workflow_model => $self,
        name => 'input connector'
    );
    return $input;
}

sub get_output_connector {
    my $self = shift;

    my $output = Cord::Operation->get(
        workflow_model => $self,
        name => 'output connector'
    );
    return $output;
}

## needs to be pulled into a viewer
sub graph {
    my $self = shift;

    my $g = GraphViz->new(
        overlap => 'compress',
        node => { shape => 'ellipse' },
    );

#    my $cluster = {
#        label => '-' . $self->name . '-',
#        style => 'filled',
#        fillcolor => 'lightgray'
#    };

    $self->add_gv_nodes($g); #,$cluster);

    return $g;
}
## needs to be pulled into a viewer
sub add_gv_nodes {
    my ($self, $g, $cluster) = @_;

    my @operations = $self->operations;
    my @links = $self->links;

    my %nodeports = ();
    my %remap_left_operation_ids = ();
    my %remap_right_operation_ids = ();
    foreach my $operation (@operations) {
        my $inputs = $operation->operation_type->input_properties;
        my $outputs = $operation->operation_type->output_properties;

        my $n = 0;
        $nodeports{$operation->id} = {};
        for (@{ $inputs }) {
            $nodeports{$operation->id}->{'IN ' . $_} = $n++;
        }
        $nodeports{$operation->id}->{'OPR' . $operation->id} = $n++;
        for (@{ $outputs }) {
            $nodeports{$operation->id}->{'OUT' . $_} = $n++;
        }

        ## percent symbols in front of the name cause graphviz to overload all the names i give it, fixing a bug

        $n = 0;

        if ($operation->isa('Cord::Model')) {

            my $cluster = {
                label => '-' . $operation->name . '-',
                style => 'filled',
                fillcolor => 'lightgray'
            };

            my $op_nodeports = $operation->add_gv_nodes($g, $cluster);

            my $input_id = $operation->get_input_connector->id; 
            my $output_id = $operation->get_output_connector->id;

            $remap_left_operation_ids{$operation->id} = $output_id;
            $remap_right_operation_ids{$operation->id} = $input_id;

            foreach my $id ($input_id, $output_id) {
                $nodeports{$id} = {};
                while (my ($k,$v) = each(%{ $op_nodeports->{$id}})) {
                    if (substr($k,0,3) eq 'IN ') {
                        substr($k,0,3,'OUT');
                    } elsif (substr($k,0,3) eq 'OUT') {
                        substr($k,0,3,'IN ');
                    }
                    $nodeports{$id}->{$k} = $v;
                }
            }

        } else {
            $g->add_node(
                '%' . $operation->id, 
                color => 'black',
                fillcolor => 'lightblue2',
                style => 'filled',
                shape => 'record',
                constraint => 0,
                cluster => $cluster,
                label => '{' .
                    (@{ $inputs } ? '{' . join('|', map { '{<port' . $n++ . '>' . $_ . '}' } @{ $inputs }) . '}' : '') .
                    '|<port' . $n++ . '>' . $operation->name . '|' . 
                    (@{ $outputs } ? '{' . join('|', map { '{<port' . $n++ . '>' . $_ . '}' } @{ $outputs }) . '}' : ''). 
                '}',
            );
        }
    }
    foreach my $link (@links) {
        my $left_operation_id = $remap_left_operation_ids{$link->left_operation->id} || $link->left_operation->id;
        my $right_operation_id = $remap_right_operation_ids{$link->right_operation->id} || $link->right_operation->id;
        $g->add_edge(
            '%' . $left_operation_id, 
            '%' . $right_operation_id,
            from_port => $nodeports{$left_operation_id}->{'OUT' . $link->left_property}, 
            to_port => $nodeports{$right_operation_id}->{'IN ' . $link->right_property} ,
        );
    }

    return \%nodeports;
}

sub as_png {
    my $self = shift;
    return $self->graph->as_png(@_);
}

sub as_ps {
    my $self = shift;
    return $self->graph->as_ps(@_);
}
sub as_text {
    my $self = shift;
    return $self->graph->as_text(@_);
}

sub as_svg {
    my $self = shift;
    return $self->graph->as_svg(@_);
}

sub validate {
    my $self = shift;
    
    my @errors = ();
    foreach my $operation ($self->operations) {  ## unique names
        my @ops_with_this_name = Cord::Operation->get(
            workflow_model => $self,
            name => $operation->name
        );
        if (scalar @ops_with_this_name > 1) {
            push @errors, "Operation name not unique: " . $self->name . '/' . $operation->name;
        }
    }

    { ## orphans 
        my @orphans = ();
        my %possible_orphans = map { $_ => $_ } $self->operations;
        my $input = $self->get_input_connector;
        my $output = $self->get_output_connector;
        
        delete $possible_orphans{$input};
        delete $possible_orphans{$output};
        
        my %looked_at = ();
        
        my @opq = ($output);
        while (scalar @opq) {
            my $op = shift @opq;
            unless ($looked_at{$op}) {
                my @depended_on_by = $op->depended_on_by;

                for (@depended_on_by) {
                    delete $possible_orphans{$_};
                }
                push @opq, @depended_on_by;
            }
            $looked_at{$op} = 1;
        }
        foreach my $operation (values %possible_orphans) {
            push @errors, "Operation or its branch disconnected: " . $self->name . '/' . $operation->name;
        }
    }

    { ## circular links
        #this is so terrible, but its easy
        
        eval {
            $self->is_valid(1);
            my @ops = $self->operations_in_series;
            $self->is_valid(0);
            
        };
        if ($@ =~ /^circular links near: '(.+?)'/) {
            push @errors, 'Operation involved in circular link: ' . $self->name . "/$1";
        } elsif ($@) {
            die $@;
        }
    }
    
    { ## connections to output
        my $output = $self->get_output_connector;
        my @depended_on_by = $output->depended_on_by;
        
        if (@depended_on_by == 0) {
            push @errors, 'Nothing connected to: ' . $self->name . '/' . $output->name;
        }
    }
        
    ## sub_models
    {
        my @submodels = Cord::Model->get(
            workflow_model => $self  ## this is confusing, workflow_model is actually the parent
        );
        
        foreach my $m (@submodels) {
            my @e = $m->validate;
            push @errors, @e;
        }
    }
    
    ## dangling links
    
    foreach my $link ($self->links) {
        my $left_output_properties = $link->left_operation->operation_type->output_properties;
        my $right_input_properties = $link->right_operation->operation_type->input_properties;
        
        my $linkdesc = $link->left_operation->name . '->' . $link->left_property . ' to ' . $link->right_operation->name . '->' . $link->right_property;
        
        if (!grep { $link->left_property eq $_ } @{ $left_output_properties }) {
            push @errors, 'Left property not found on link: ' . $linkdesc;
        }

        if (!grep { $link->right_property eq $_ } @{ $right_input_properties }) {
            push @errors, 'Right property not found on link: ' . $linkdesc;
        }
    }
    
    if (@errors == 0) {
        $self->is_valid(1);
    } else {
        $self->is_valid(0);
    }
    
    return @errors;
}

# make a list of operations in the order of execution
sub operations_in_series {
    my $self = shift;

    unless ($self->is_valid) {
        my @errors = $self->validate;
        unless (@errors == 0) {
            die 'cannot build an operations series for invalid workflow';
        }
    }
    
    my %operation_tiers = map {
        $_->name => [0,$_]
    } $self->operations;

    my $maxdepth = keys %operation_tiers;
    my $depth = 0;
    my $move_deps_down;
    $move_deps_down = sub {
        my ($op,$tier) = @_;
        
        if ($depth > $maxdepth) {
            die 'circular links near: \'' . $op->name . '\'';
        }
        $operation_tiers{$op->name}->[0] = $tier;

        for ($op->dependent_operations) {
            my $new_tier = $tier + 1;
            $depth++; ## stupid way of detecting recursion
            $move_deps_down->($_,$new_tier);
            $depth--;
        }
    };
    
    foreach my $tier (0..$maxdepth) {
        my @ops = map {
            $operation_tiers{$_}->[1]
        } grep {
            $operation_tiers{$_}->[0] == $tier
        } keys %operation_tiers;
        
        foreach my $operation (@ops) {
            next if ($operation_tiers{$operation->name}->[0] != $tier); #it got moved
            $move_deps_down->($operation,$tier);
        }
    }
    
    my @op_order = map {
        $_->[1]
    } sort {
        $a->[0] <=> $b->[0] ||
        $a->[1]->name cmp $b->[1]->name
    } values %operation_tiers;

    return @op_order;
}

sub set_all_executor {
    my ($self, $executor) = @_;
    
    $self->executor($executor);
    
    foreach my $op ($self->operations) {
        if ($op->isa('Cord::Model')) {
            $op->set_all_executor($executor);
        }
    }
    
    return $self->executor;
}

1;