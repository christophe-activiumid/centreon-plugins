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

package storage::huawei::oceanstor::restapi::mode::luns;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);
use storage::huawei::oceanstor::restapi::mode::resources qw($health_status $running_status);

sub lun_status_output {
    my ($self, %options) = @_;

    return sprintf(
        'health status: %s [running status: %s]',
        $self->{result_values}->{health_status},
        $self->{result_values}->{running_status}
    );
}

sub custom_space_usage_output {
    my ($self, %options) = @_;

    my ($total_size_value, $total_size_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{total_space});
    my ($total_used_value, $total_used_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{used_space});    
    my ($total_prot_value, $total_prot_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{prot_space});
    return sprintf(
        'size: %s used: %s (%.2f%%) protection: %s',
        $total_size_value . " " . $total_size_unit,
        $total_used_value . " " . $total_used_unit, 
        $self->{result_values}->{prct_used_space},        
        $total_prot_value . " " . $total_prot_unit
    );
}

sub lun_long_output {
    my ($self, %options) = @_;

    return sprintf(
        "checking LUN '%s' [sp: %s]",
        $options{instance_value}->{name},
        $options{instance_value}->{storage_pool}
    );
}

sub prefix_lun_output {
    my ($self, %options) = @_;

    return sprintf(
        "LUN '%s' [sp: %s] ",
        $options{instance_value}->{name},
        $options{instance_value}->{storage_pool}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'lun', type => 3, cb_prefix_output => 'prefix_lun_output', cb_long_output => 'lun_long_output', indent_long_output => '    ', message_multiple => 'All LUNs are ok',
            group => [
                { name => 'space', type => 0 }
            ]
        }
    ];

    $self->{maps_counters}->{space} = [
         { label => 'usage', nlabel => 'space.usage.bytes', set => {
                key_values => [ { name => 'used_space' },  { name => 'total_space' },{ name => 'prct_used_space' }, { name => 'prot_space' }],
                closure_custom_output => $self->can('custom_space_usage_output'),                
                perfdatas => [
                    { template => '%d', min => 0, max => 'total_space', unit => 'B', cast_int => 1, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'usage-prct', nlabel => 'space.usage.percentage', display_ok => 0, set => {
                key_values => [ { name => 'prct_used_space' } ],
                output_template => 'space used : %.2f %%',
                perfdatas => [
                    { label => 'used_prct', value => 'prct_used_space', template => '%.2f', min => 0, max => 100, unit => '%' }
                ]
            }
        },
        { label => 'usage-protection', nlabel => 'space.protection.bytes', display_ok => 0, set => {                
                key_values => [ { name => 'prot_space' },  { name => 'total_space' }],
                output_template => 'protection space used : %.2f %%',
                output_change_bytes => 1,
                perfdatas => [
                    { value => 'prot_space', template => '%d', min => 0, max => 'total_space', unit => 'B', cast_int => 1 },
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
        'filter-name:s' => { name => 'filter_name' },
    });
    
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
}

sub manage_selection {
    my ($self, %options) = @_;

    my $result = $options{custom}->request(endpoint => '/lun');
    my $data = $result->{data};
    
    $self->{lun} = {};
    
    foreach my $lun (@$data) {
        if(defined $lun->{'functionType'} ){      #this only for V6 where luns include snapshots, not on V5
            next if($lun->{'functionType'} != 1); # functionType==1 means a LUN, skip otherwhise.
        }
        
        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $lun->{'NAME'} !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(long_msg => "skipping LUN '" . $lun->{'NAME'} . "'.", debug => 1);
            next;
        }

        my $total = $lun->{'CAPACITY'} * $lun->{'SECTORSIZE'};
        my $used = $lun->{'ALLOCCAPACITY'} * $lun->{'SECTORSIZE'};
        my $free = $total - $used;
        my $prct = $used * 100 / $total;
        
        my $prot = $lun->{'REPLICATION_CAPACITY'} * $lun->{'SECTORSIZE'};
        
        $self->{lun}->{ $lun->{'NAME'} } = {
            name => $lun->{'NAME'},
            storage_pool => $lun->{'PARENTNAME'},
            health => {
                name => $lun->{'NAME'},
                health_status => $health_status->{$lun->{'HEALTHSTATUS'}},
                running_status => $running_status->{$lun->{'RUNNINGSTATUS'}}
            },
            space => {
                 total_space => $total,
                 used_space => $used,
                 free_space => $free, 
                 prot_space => $prot,                 
                 prct_used_space => $prct
             }
        } 
    }
}

1;

__END__

=head1 MODE

Check Lun usage

=over 8

=item B<--filter-name>

Filter lun by name (can be a regexp).

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'space-usage', 'space-usage-prct', 'space-usage-prot'.

=back

=cut