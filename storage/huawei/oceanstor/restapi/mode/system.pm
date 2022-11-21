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

package storage::huawei::oceanstor::restapi::mode::system;
#use Data::Dumper;

use strict;
use warnings;

use base qw(centreon::plugins::templates::counter);
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);
use storage::huawei::oceanstor::restapi::mode::resources qw($health_status $running_status );

sub system_status_output {
    my ($self, %options) = @_;

    return sprintf(
        'health status: %s [running status: %s]',
        $self->{result_values}->{health_status},
        $self->{result_values}->{running_status}
    );
}

sub system_space_usage_output {
    my ($self, %options) = @_;

    my ($total_size_value, $total_size_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{total_space});
    my ($total_used_value, $total_used_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{used_space});
    return sprintf(
        'capacity: %s used: %s (%.2f%%)',
        $total_size_value . " " . $total_size_unit,
        $total_used_value . " " . $total_used_unit, 
        $self->{result_values}->{prct_used_space}
    );
}
sub system_long_output {
    my ($self, %options) = @_;

    return sprintf(
        "checking system '%s' ",
        $options{instance_value}->{name}
    );
}

sub prefix_system_output {
    my ($self, %options) = @_;

    return sprintf(
        "System '%s' (sn: %s), model : %s, os: %s, ",
        $options{instance_value}->{name},
        $options{instance_value}->{id},
        $options{instance_value}->{model},
        $options{instance_value}->{os}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'syst', type => 3, cb_prefix_output => 'prefix_system_output', cb_long_output => 'system_long_output',
          indent_long_output => '    ', message_multiple => 'All systems are ok',
            group => [
                { name => 'space', type => 0, skipped_code => { -10 => 1 } },
                { name => 'status', type => 0, skipped_code => { -10 => 1 } }
            ]
        }
    ];

    $self->{maps_counters}->{space} = [
         { label => 'usage', nlabel => 'space.usage.bytes', set => {
                key_values => [ { name => 'used_space' },  { name => 'total_space' },{ name => 'prct_used_space' }],
                closure_custom_output => $self->can('system_space_usage_output'),
                perfdatas => [
                    { template => '%d', min => 0, max => 'total_space', unit => 'B', cast_int => 1, label_extra_instance => 1 }
                ]
            }
        }
    ];
    
    $self->{maps_counters}->{status} = [
        {
            label => 'health status',
            type => 2,
            warning_default => '%{health_status} =~ /degraded|partially broken/i',
            critical_default => '%{health_status} =~ /faulty|fail/i',
            set => {
                key_values => [ { name => 'health_status' }, { name => 'running_status' }, { name => 'name' } ],
                closure_custom_output => $self->can('system_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $result = $options{custom}->request(endpoint => '/system/');
    my $data = $result->{data};
    
    
    my $total=$data->{'STORAGEPOOLCAPACITY'} * $data->{'SECTORSIZE'};
    my $used=$data->{'STORAGEPOOLUSEDCAPACITY'} * $data->{'SECTORSIZE'};
    my $free=$total - $used;
    my $prct=$used * 100 / $total;
    
    $self->{syst}->{ $data->{'NAME'} } = {
        name => $data->{'NAME'},  
        id => $data->{'ID'},
        model => $data->{'productModeString'},
        os => $data->{'pointRelease'},
        space => {
             total_space => $total,
             used_space => $used,
             free_space => $free, 
             prct_used_space => $prct
        },
        status => {
            name => $data->{'NAME'},
            health_status => $health_status->{$data->{'HEALTHSTATUS'}},
            running_status => $running_status->{$data->{'RUNNINGSTATUS'}}
        }
    }
}

1;

__END__

=head1 MODE

Check Storage Pool usage

=over 8

=item B<--filter-name>

Filter storage pool by name (can be a regexp).

=back

=cut