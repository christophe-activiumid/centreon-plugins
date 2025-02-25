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
#

package database::redis::mode::clients;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub prefix_output {
    my ($self, %options) = @_;
    
    return 'Clients ';
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_output', skipped_code => { -10 => 1 } }
    ];
    
    $self->{maps_counters}->{global} = [
        { label => 'connected-clients', nlabel => 'clients.connected.count', set => {
                key_values => [ { name => 'connected_clients' } ],
                output_template => 'connected: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'blocked-clients', nlabel => 'clients.blocked.count', set => {
                key_values => [ { name => 'blocked_clients' } ],
                output_template => 'blocked: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'client-longest-output-list', nlabel => 'clients.longest_output_list.count', set => {
                key_values => [ { name => 'client_longest_output_list' } ],
                output_template => 'longest output list: %s',
                perfdatas => [
                    { label => 'client_longest_output_list', template => '%s', min => 0 }
                ]
            }
        },
        { label => 'client-biggest-input-buf', nlabel => 'clients.biggest_input_buffer.count', set => {
                key_values => [ { name => 'client_biggest_input_buf' } ],
                output_template => 'client biggest input buffer: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {});

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $results = $options{custom}->get_info();
    $self->{global} = {
        connected_clients          => $results->{connected_clients},
        blocked_clients            => $results->{blocked_clients},
        client_longest_output_list => $results->{client_longest_output_list},
        client_biggest_input_buf   => $results->{client_biggest_input_buf}
    };
}

1;

__END__

=head1 MODE

Check number of connected and blocked clients

=over 8

=item B<--warning-connected-clients>

Warning threshold for number of connected clients

=item B<--critical-connected-clients>

Critical threshold for number of connected clients

=item B<--warning-blocked-clients>

Warning threshold for number of blocked clients

=item B<--critical-blocked-clients>

Critical threshold for number of blocked clients

=item B<--warning-client-longest-output-list>

Warning threshold for longest output list among current client connections

=item B<--critical-client-longest-output-list>

Critical threshold for longest output list among current client connections

=item B<--warning-client-biggest-input-buf>

Warning threshold for biggest input buffer among current client connections

=item B<--critical-client-biggest-input-buf>

Critical threshold for biggest input buffer among current client connections

=back

=cut
