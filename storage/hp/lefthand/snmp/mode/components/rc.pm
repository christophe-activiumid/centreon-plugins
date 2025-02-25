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

package storage::hp::lefthand::snmp::mode::components::rc;

use strict;
use warnings;
use storage::hp::lefthand::snmp::mode::components::resources qw($map_status);

my $mapping = {
    storageRaidDeviceName   => { oid => '.1.3.6.1.4.1.9804.3.1.1.2.4.4.1.2' },
    storageRaidDeviceState  => { oid => '.1.3.6.1.4.1.9804.3.1.1.2.4.4.1.90' },
    storageRaidDeviceStatus => { oid => '.1.3.6.1.4.1.9804.3.1.1.2.4.4.1.91', map => $map_status },
};
my $oid_storageRaidEntry = '.1.3.6.1.4.1.9804.3.1.1.2.4.4.1';

sub load {
    my ($self) = @_;
    
    push @{$self->{request}}, { oid => $oid_storageRaidEntry };
}

sub check {
    my ($self) = @_;
    
    $self->{output}->output_add(long_msg => "Checking raid controllers");
    $self->{components}->{rc} = {name => 'raid controllers', total => 0, skip => 0};
    return if ($self->check_filter(section => 'rc'));

    foreach my $oid ($self->{snmp}->oid_lex_sort(keys %{$self->{results}->{$oid_storageRaidEntry}})) {
        next if ($oid !~ /^$mapping->{storageRaidDeviceStatus}->{oid}\.(.*)$/);
        my $instance = $1;
        my $result = $self->{snmp}->map_instance(mapping => $mapping, results => $self->{results}->{$oid_storageRaidEntry}, instance => $instance);

        next if ($self->check_filter(section => 'rc', instance => $instance));
        $self->{components}->{rc}->{total}++;
        
        $self->{output}->output_add(long_msg => sprintf("raid device controller '%s' status is '%s' [instance: %s, state: %s].",
                                    $result->{storageRaidDeviceName}, $result->{storageRaidDeviceStatus},
                                    $instance, $result->{storageRaidDeviceState}
                                    ));
        my $exit = $self->get_severity(label => 'default', section => 'rc', value => $result->{storageRaidDeviceStatus});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(severity =>  $exit,
                                        short_msg => sprintf("raid device controller '%s' state is '%s'",
                                                             $result->{storageRaidDeviceName}, $result->{storageRaidDeviceState}));
        }
    }
}

1;