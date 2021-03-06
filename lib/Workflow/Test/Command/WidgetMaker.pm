package Workflow::Test::Command::WidgetMaker;

use strict;
use warnings;

use Workflow;
use Command; 

use Workflow::Test::Widget;

class Workflow::Test::Command::WidgetMaker {
    is => ['Workflow::Test::Command'],
    has_input => [
        size => { },
        color => { },
        shape => { },
    ],
    has_output => [
        widget => { is_optional => 1 },
    ],
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "Sleeps for the specified number of seconds";
}

sub help_synopsis {
    return <<"EOS"
    workflow-test 
EOS
}

sub help_detail {
    return <<"EOS"
This command is used for testing purposes.
EOS
}

sub execute {
    my $self = shift;

    my $w = Workflow::Test::Widget->new({
        size => $self->size,
        color => $self->color,
        shape => $self->shape
    });
    
    $self->widget($w);
    
    return 1;
}
 
1;
