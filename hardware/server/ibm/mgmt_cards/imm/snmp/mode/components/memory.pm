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

package hardware::server::ibm::mgmt_cards::imm::snmp::mode::components::memory;

use strict;
use warnings;
use centreon::plugins::misc;

my $mapping = {
    memoryDescr        => { oid => '.1.3.6.1.4.1.2.3.51.3.1.5.21.1.2' },
    memoryHealthStatus => { oid => '.1.3.6.1.4.1.2.3.51.3.1.5.21.1.8' }
};
my $oid_memoryEntry = '.1.3.6.1.4.1.2.3.51.3.1.5.21.1';

sub load {
    my ($self) = @_;
    
    push @{$self->{request}}, { oid => $oid_memoryEntry, start => $mapping->{memoryDescr}->{oid}, end => $mapping->{memoryHealthStatus}->{oid} };
}

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => "Checking memorys");
    $self->{components}->{memory} = { name => 'memorys', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'memory'));
    
    foreach my $oid ($self->{snmp}->oid_lex_sort(keys %{$self->{results}->{$oid_memoryEntry}})) {
        next if ($oid !~ /^$mapping->{memoryDescr}->{oid}\.(.*)$/);
        my $instance = $1;
        my $result = $self->{snmp}->map_instance(mapping => $mapping, results => $self->{results}->{$oid_memoryEntry}, instance => $instance);

        next if ($self->check_filter(section => 'memory', instance => $instance));

        $self->{components}->{memory}->{total}++;
        # HealthStatus OIDs are only available with IMM v2
        next if !defined($result->{memoryHealthStatus});
        $self->{output}->output_add(
            long_msg => sprintf(
                "memory '%s' is '%s' [instance = %s]",
                $result->{memoryDescr}, $result->{memoryHealthStatus}, $instance
            )
        );
        my $exit = $self->get_severity(label => 'health', section => 'memory', value => $result->{memoryHealthStatus});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Memory '%s' is '%s'", $result->{memoryDescr}, $result->{memoryHealthStatus})
            );
        }
    }
}

1;
