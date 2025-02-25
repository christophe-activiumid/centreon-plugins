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

package network::hp::vc::snmp::mode::components::module;

use strict;
use warnings;
use network::hp::vc::snmp::mode::components::resources qw($map_managed_status $map_reason_code);

my $mapping = {
    vcModuleProductName => { oid => '.1.3.6.1.4.1.11.5.7.5.2.1.1.3.1.1.6' },
    vcModuleManagedStatus => { oid => '.1.3.6.1.4.1.11.5.7.5.2.1.1.3.1.1.3', map => $map_managed_status },
    vcModuleReasonCode => { oid => '.1.3.6.1.4.1.11.5.7.5.2.1.1.3.1.1.15', map => $map_reason_code },
};
my $oid_vcModuleEntry = '.1.3.6.1.4.1.11.5.7.5.2.1.1.3.1.1';

sub load {
    my ($self) = @_;
    
    push @{$self->{request}}, { oid => $oid_vcModuleEntry };
}

sub check {
    my ($self) = @_;
    
    $self->{output}->output_add(long_msg => "Checking modules");
    $self->{components}->{module} = { name => 'modules', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'module'));

    foreach my $oid ($self->{snmp}->oid_lex_sort(keys %{$self->{results}->{$oid_vcModuleEntry}})) {
        next if ($oid !~ /^$mapping->{vcModuleManagedStatus}->{oid}\.(.*)$/);
        my $instance = $1;
        my $result = $self->{snmp}->map_instance(mapping => $mapping, results => $self->{results}->{$oid_vcModuleEntry}, instance => $instance);

        next if ($self->check_filter(section => 'module', instance => $instance));
        $self->{components}->{module}->{total}++;

        $self->{output}->output_add(long_msg => sprintf("module '%s' status is '%s' [instance: %s, reason: %s].",
                                    $result->{vcModuleProductName}, $result->{vcModuleManagedStatus},
                                    $instance, $result->{vcModuleReasonCode}
                                    ));
        my $exit = $self->get_severity(section => 'module', label => 'default', value => $result->{vcModuleManagedStatus});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(severity =>  $exit,
                                        short_msg => sprintf("Module '%s' status is '%s'",
                                                             $result->{vcModuleProductName}, $result->{vcModuleManagedStatus}));
        }
    }
}

1;