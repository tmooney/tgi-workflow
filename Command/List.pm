package Workflow::Store::Db::Operation::RootInstance;

use strict;
use warnings;

use Workflow;
use Command; 

class Workflow::Store::Db::Operation::RootInstance {
    table_name => "
        (SELECT wi.workflow_instance_id, wi.name, wie.status 
           FROM workflow.workflow_instance wi
           JOIN workflow.workflow_instance_execution wie ON (wi.current_execution_id = wie.workflow_execution_id)
          WHERE wi.parent_instance_id IS NULL 
            AND (wi.peer_instance_id IS NULL OR wi.peer_instance_id = wi.workflow_instance_id)) workflow_instance", 
    id_properties => ['workflow_instance_id'],
    has => [
        workflow_instance_id => { is => 'Number' },
        name => { is => 'Varchar2' },
        status => { is => 'Varchar2' }, 
    ],
    data_source => 'Workflow::DataSource::InstanceSchema'
};

package Workflow::Command::List;

class Workflow::Command::List {
    is => ['UR::Object::Command::List'],
    has_constant => [
        subject_class_name => {
            value => 'Workflow::Store::Db::Operation::RootInstance'
        },
    ],
    has => [
        show => {
            default_value => 'workflow_instance_id,name,status'
        }
    ]
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "List";
}

sub help_synopsis {
    return <<"EOS"
    workflow list 
EOS
}

sub help_detail {
    return <<"EOS"
This command is used for diagnostic purposes.
EOS
}

#sub _base_filter {
#    'parent_instance_id=,peer_instance_id='
#}
 
1;