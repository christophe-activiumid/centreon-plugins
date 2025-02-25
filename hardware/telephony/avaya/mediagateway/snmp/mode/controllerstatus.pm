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

package hardware::telephony::avaya::mediagateway::snmp::mode::controllerstatus;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions;

sub custom_status_output {
    my ($self, %options) = @_;
    
    my $msg = sprintf("controller registration state is '%s' [h248 link status: '%s']", $self->{result_values}->{registration_state}, $self->{result_values}->{h248_link_status});
    return $msg;
}

sub custom_status_calc {
    my ($self, %options) = @_;
    
    $self->{result_values}->{registration_state} = $options{new_datas}->{$self->{instance} . '_cmgRegistrationState'};
    $self->{result_values}->{h248_link_status} = $options{new_datas}->{$self->{instance} . '_cmgH248LinkStatus'};
    return 0;
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'global', type => 0 },
    ];
        
    $self->{maps_counters}->{global} = [
         { label => 'status', threshold => 0, set => {
                key_values => [ { name => 'cmgRegistrationState' }, { name => 'cmgH248LinkStatus' } ],
                closure_custom_calc => $self->can('custom_status_calc'),
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&centreon::plugins::templates::catalog_functions::catalog_status_threshold,
            }
        },
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
        'unknown-status:s'  => { name => 'unknown_status', default => '' },
        'warning-status:s'  => { name => 'warning_status', default => '' },
        'critical-status:s' => { name => 'critical_status', default => '%{h248_link_status} =~ /down/i || %{registration_state} =~ /notRegistred/i' },
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);

    $self->change_macros(macros => ['warning_status', 'critical_status', 'unknown_status']);
}

my %map_registration_state = (
    1 => 'registred',
    2 => 'notRegistred',
);
my %map_h248_link_status = (
    1 => 'up',
    2 => 'down',
);

my $mapping = {
    cmgRegistrationState    => { oid => '.1.3.6.1.4.1.6889.2.9.1.3.1', map => \%map_registration_state },
    cmgH248LinkStatus       => { oid => '.1.3.6.1.4.1.6889.2.9.1.3.3', map => \%map_h248_link_status },
};

sub manage_selection {
    my ($self, %options) = @_;

    
    my $snmp_result = $options{snmp}->get_leef(
        oids => [$mapping->{cmgRegistrationState}->{oid} . '.0', $mapping->{cmgH248LinkStatus}->{oid} . '.0'],
        nothing_quit => 1
    );

    my $result = $options{snmp}->map_instance(mapping => $mapping, results => $snmp_result, instance => '0');
    $self->{global} = { %$result };
}

1;

__END__

=head1 MODE

Check controller status.

=over 8

=item B<--unknown-status>

Set unknown threshold for status (Default: '').
Can used special variables like: %{h248_link_status}, %{registration_state}

=item B<--warning-status>

Set warning threshold for status (Default: '').
Can used special variables like: %{h248_link_status}, %{registration_state}

=item B<--critical-status>

Set critical threshold for status (Default: '%{h248_link_status} =~ /down/i || %{registration_state} =~ /notRegistred/i').
Can used special variables like: %{h248_link_status}, %{registration_state}

=back

=cut
