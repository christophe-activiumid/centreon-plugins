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

package network::athonet::epc::snmp::mode::listinterfacesga;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
    });
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
}

my $map_status = { 0 => 'down', 1 => 'up' };
my $map_transport_type = { 0 => 'sctp', 1 => 'tcp', 2 => 'udp' };

my $mapping = {
    local_address => { oid => '.1.3.6.1.4.1.35805.10.2.12.10.1.2' }, # iGaLinkLocalAddress
    peer_address  => { oid => '.1.3.6.1.4.1.35805.10.2.12.10.1.3' }, # iGaLinkPeerAddress
    type          => { oid => '.1.3.6.1.4.1.35805.10.2.12.10.1.4', map => $map_transport_type }, # iGaLinkTransportType
    status        => { oid => '.1.3.6.1.4.1.35805.10.2.12.10.1.5', map => $map_status },  # iGaLinkState
    name          => { oid => '.1.3.6.1.4.1.35805.10.2.12.10.1.7' }, # iGaLinkName
};
my $oid_gaLinksEntry = '.1.3.6.1.4.1.35805.10.2.12.10.1';

sub manage_selection {
    my ($self, %options) = @_;

    my $snmp_result = $options{snmp}->get_table(
        oid => $oid_gaLinksEntry,
        nothing_quit => 1
    );

    my $results = {};
    foreach (keys %$snmp_result) {
        next if (! /^$mapping->{local_address}->{oid}\.(.*)$/);
        my $instance = $1;

        $results->{$instance} = $options{snmp}->map_instance(mapping => $mapping, results => $snmp_result, instance => $instance);
    }

    return $results;
}

sub run {
    my ($self, %options) = @_;

    my $results = $self->manage_selection(snmp => $options{snmp});
    foreach my $name (sort keys %$results) {
        $self->{output}->output_add(long_msg => 
            join('', map("[$_ = " . $results->{$name}->{$_} . ']', keys(%$mapping)))
        );
    }

    $self->{output}->output_add(
        severity => 'OK',
        short_msg => 'List ga interfaces:'
    );
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
    $self->{output}->exit();
}

sub disco_format {
    my ($self, %options) = @_;

    $self->{output}->add_disco_format(elements => [keys %$mapping]);
}

sub disco_show {
    my ($self, %options) = @_;

    my $results = $self->manage_selection(snmp => $options{snmp});
    foreach (sort keys %$results) {        
        $self->{output}->add_disco_entry(
            %{$results->{$_}}
        );
    }
}

1;

__END__

=head1 MODE

List GA interfaces.

=over 8

=back

=cut
