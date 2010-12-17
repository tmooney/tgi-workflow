package Workflow::Operation::Instance::View::Metrics::Xml;

our @aspects = qw/name status start_time end_time elapsed_time operation_type parallel_index is_parallel/;

push @aspects,
  {
    name               => 'current',
    subject_class_name => 'Workflow::Operation::InstanceExecution',
    perspective        => 'default',
    toolkit            => 'xml',
    aspects => [
      {
        name => 'metrics',
        aspects => [
          'name',
          'value'
        ],
        perspective => 'default',
        toolkit => 'xml',
        subject_class_name => 'Workflow::Operation::InstanceExecution::Metric',
      },
    ]
  };

class Workflow::Operation::Instance::View::Metrics::Xml {
    is  => 'Workflow::Operation::Instance::View::Default::Xml',
    has => [
        default_aspects =>
          { value => [ 'cache_workflow_id', @aspects, &related_instances(0) ] },
    ]
};

#TODO clean up this ugly way to specify aspects

sub related_instances {
    return if $_[0] > 10;

    return {
        name               => 'related_instances',
        subject_class_name => 'Workflow::Operation::Instance',
        perspective        => 'status',
        toolkit            => 'xml',
        aspects => [ @aspects, &related_instances( $_[0] + 1 ) ]
    };
}

1;
