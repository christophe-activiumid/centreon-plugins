#
# Copyright 2022 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# Authors : Christophe Niel - Activium ID

package storage::huawei::oceanstor::restapi::mode::controllers;
use Data::Dumper;
use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);
use storage::huawei::oceanstor::restapi::mode::resources qw($health_status $running_status $model);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        'health status: %s [running status: %s]',
        $self->{result_values}->{health_status},
        $self->{result_values}->{running_status}
    );
}
sub custom_cluster_output {
    my ($self, %options) = @_;

    return sprintf(
        'is cluster master: %s',
        $self->{result_values}->{is_master}
    );
}

sub ctrl_long_output {
    my ($self, %options) = @_;

    return sprintf(
        "checking controller '%s' - Model %s",
        $options{instance_value}->{id},
        $options{instance_value}->{model},
    );
}

sub prefix_ctrl_output {
    my ($self, %options) = @_;

    return sprintf(
        "controller '%s' ",
        $options{instance_value}->{id}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'controllers', type => 3, cb_prefix_output => 'prefix_ctrl_output', cb_long_output => 'ctrl_long_output',
          indent_long_output => '    ', message_multiple => 'All controllers are ok',
            group => [
                { name => 'status', type => 0, skipped_code => { -10 => 1 } },
                { name => 'cluster', type => 0, skipped_code => { -10 => 1 } },
                { name => 'cpu', type => 0, skipped_code => { -10 => 1 } },
                { name => 'memory', type => 0, skipped_code => { -10 => 1 } }
            ]
        }
    ];

    $self->{maps_counters}->{status} = [
        {
            label => 'status',
            type => 2,
            warning_default => '%{health_status} =~ /degraded|partially broken/i',
            critical_default => '%{health_status} =~ /fault|fail/i',
            set => {
                key_values => [ { name => 'health_status' }, { name => 'running_status' }, { name => 'id' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];
    
    $self->{maps_counters}->{cluster} = [
        {
            label => 'cluster',
            type => 2,
            warning_default => '',
            critical_default => '',
            set => {
                key_values => [ { name => 'is_master' } ],
                closure_custom_output => $self->can('custom_cluster_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];

    $self->{maps_counters}->{cpu} = [
         { label => 'cpu-utilization', nlabel => 'controller.cpu.utilization.percentage', set => {
                key_values => [ { name => 'cpu_usage' } ],
                output_template => 'cpu usage: %.2f %%',
                perfdatas => [
                    { template => '%.2f', unit => '%', min => 0, max => 100, label_extra_instance => 1 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{memory} = [
         { label => 'memory-usage', nlabel => 'controller.memory.usage.percentage', set => {
                key_values => [ { name => 'memory_usage' } ],
                output_template => 'memory used: %.2f %%',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%.2f', unit => '%', min => 0, max => 100, label_extra_instance => 1 }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-id:s' => { name => 'filter_id' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $result = $options{custom}->request(endpoint => '/controller');
    my $data = $result->{data};

    $self->{controllers} = {};
    
    foreach my $ctrl (@$data) {                
        if (defined($self->{option_results}->{filter_id}) && $self->{option_results}->{filter_id} ne '' &&
            $ctrl->{'ID'} !~ /$self->{option_results}->{filter_id}/) {
            $self->{output}->output_add(long_msg => "skipping controller '" . $ctrl->{'ID'} . "'.", debug => 1);
            next;
        }
        
        $self->{controllers}->{ $ctrl->{'ID'} } = {
            id =>$ctrl->{'ID'},
            model => $model->{$ctrl->{'MODEL'}},
            memory => { memory_usage => $ctrl->{'MEMORYUSAGE'} },
            cpu => { cpu_usage => $ctrl->{'CPUUSAGE'} },
            status => {
                running_status => $running_status->{$ctrl->{'RUNNINGSTATUS'}},
                health_status =>  $health_status->{$ctrl->{'HEALTHSTATUS'}},
                id => $ctrl->{'ID'}
            },
            cluster => {
               is_master => $ctrl->{'ISMASTER'},
            }
        }
    };

    return if (scalar(keys %{$self->{controllers}}) <= 0);
    
}

sub disco_format {
    my ($self, %options) = @_;

    $self->{output}->add_disco_format(elements => ['name', 'id']);
}

sub disco_show {
    my ($self, %options) = @_;

    my $result = $self->manage_selection(custom => $options{custom});
    my $data = $result->{data};

    foreach my $lun (@$data) {
        next if($lun->{'functionType'} != 1); 
        $self->{output}->add_disco_entry( name => $lun->{'NAME'}, id => $lun->{'ID'} );
    }
}

1;

__END__

=head1 MODE

Check controllers.

=over 8

=item B<--filter-id>

Filter controller by ID (can be a regexp).

=item B<--unknown-status>

Set unknown threshold for status.
Can used special variables like: %{health_status}, %{running_status}, %{id}

=item B<--warning-status>

Set warning threshold for status (Default: '%{health_status} =~ /degraded|partially broken/i').
Can used special variables like: %{health_status}, %{running_status}, %{id}

=item B<--critical-status>

Set critical threshold for status (Default: '%{health_status} =~ /fault|fail/i').
Can used special variables like: %{health_status}, %{running_status}, %{id}

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'cpu-utilization', 'memory-usage'.

=back

=cut
