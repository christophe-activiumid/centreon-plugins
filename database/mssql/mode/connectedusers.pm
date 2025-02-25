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

package database::mssql::mode::connectedusers;

use strict;
use warnings;
use base qw(centreon::plugins::templates::counter);

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {});

    return $self;
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'connected_user', type => 0 },
    ];

    $self->{maps_counters}->{connected_user} = [
        { label => 'connected-user', nlabel => 'mssql.users.connected.count', set => {
                key_values => [ { name => 'value' } ],
                output_template => '%i connected user(s)',
                perfdatas => [
                    { template => '%i', min => 0 },
                ],
            }
        },
    ];
}

sub manage_selection {
    my ($self, %options) = @_;

    $options{sql}->connect();
    $options{sql}->query(query => q{SELECT count(*) FROM master..sysprocesses WHERE spid >= '51'});

    my $connected_count = $options{sql}->fetchrow_array();
    $self->{connected_user}->{value} = $connected_count;

}

1;

__END__

=head1 MODE

Check MSSQL connected users.

=over 8

=item B<--warning-connected-user>

Threshold warning.

=item B<--critical-connected-user>

Threshold critical.

=back

=cut
