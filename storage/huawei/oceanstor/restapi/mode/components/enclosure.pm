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

package storage::huawei::oceanstor::restapi::mode::components::enclosure;

use strict;
use warnings;
use storage::huawei::oceanstor::restapi::mode::resources qw($health_status $running_status $model);


sub load {}

sub check {
    my ($self) = @_;

my $logictype = {
    0 => 'disk enclosure',
    1 => 'controller enclosure',
    2 => 'data switch',
    3 => 'management switch',
    4 => 'management server'
};    
    
    $self->{output}->output_add(long_msg => 'checking enclosures');
    $self->{components}->{enclosure} = { name => 'enclosures', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'enclosure'));
    
    my ($exit, $warn, $crit, $checked);    
    foreach my $entry (@{$self->{subsystems}->{enclosure}}) {
        my $instance = $entry->{'ID'};
        my $name = $entry->{'NAME'};

        next if ($self->check_filter(section => 'enclosure', instance => $instance, name => $name));
        
        $self->{components}->{enclosure}->{total}++;
        $self->{output}->output_add(
            long_msg => sprintf(
                "enclosure instance '%s' status is '%s' [type: %s, model: %s, name: %s, running status: %s, temperature: %s]",
                $instance,
                $health_status->{$entry->{'HEALTHSTATUS'}},
                $logictype->{$entry->{'LOGICTYPE'}},
                $model->{$entry->{'MODEL'}},                
                $entry->{'NAME'},
                $running_status->{$entry->{'RUNNINGSTATUS'}},
                $entry->{'TEMPERATURE'}
            )
        );
        
        $exit = $self->get_severity(label => 'default', section => 'enclosure', name => $name, value => $health_status->{$entry->{'HEALTHSTATUS'}});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf(
                    "Enclosure '%s' status is '%s'",
                    $instance,
                    $health_status->{$entry->{'HEALTHSTATUS'}}
                )
            );
        }
        
        ($exit, $warn, $crit, $checked) = $self->get_severity_numeric(section => 'enclosure.temperature', instance => $instance, name => $name, value => $entry->{'TEMPERATURE'});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Enclosure temperature '%s' is '%s' C", $instance, $entry->{'TEMPERATURE'})
            );
        } 
        
        $self->{output}->perfdata_add(
            nlabel => 'hardware.enclosure.temperature.celsius',
            unit => 'C',
            instances => $instance,
            value => $entry->{'TEMPERATURE'},
            warning => $warn,
            critical => $crit
        );
    }
}

1;