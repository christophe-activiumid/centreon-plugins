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

package storage::hp::storeonce::4::restapi::mode::components::temperature;

use strict;
use warnings;

sub load {}

sub check {
    my ($self) = @_;
    
    $self->{output}->output_add(long_msg => 'checking temperatures');
    $self->{components}->{temperature} = { name => 'temperature', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'temperature'));

    foreach my $entry (@{$self->{subsystems}->{tempSensor}}) {
        my $instance = $entry->{name};
        next if ($self->check_filter(section => 'temperature', instance => $instance));
        $self->{components}->{temperature}->{total}++;

        $self->{output}->output_add(
            long_msg => sprintf(
                "temperature '%s' status is %s [current: %s]",
                $entry->{name},
                $entry->{status},
                $entry->{temperature}
            )
        );
        my $exit = $self->get_severity(label => 'default', section => 'temperature', value => $entry->{status});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity =>  $exit,
                short_msg => sprintf(
                    "temperature '%s' status is %s",
                    $entry->{name}, $entry->{status}
                )
            );
        }
        
        next if (!defined($entry->{temperature}));

        my ($exit2, $warn, $crit, $checked) = $self->get_severity_numeric(section => 'temperature', instance => $instance, value => $entry->{temperature});
        if ($checked == 0) {
            my $warn_th = defined($entry->{upperNonCriticalThreshold}) ? $entry->{upperNonCriticalThreshold} : '';
            my $crit_th = defined($entry->{upperCriticalThreshold}) ? $entry->{upperCriticalThreshold} : '';
            
            $self->{perfdata}->threshold_validate(label => 'warning-temperature-instance-' . $instance, value => $warn_th);
            $self->{perfdata}->threshold_validate(label => 'critical-temperature-instance-' . $instance, value => $crit_th);
            $warn = $self->{perfdata}->get_perfdata_for_output(label => 'warning-temperature-instance-' . $instance);
            $crit = $self->{perfdata}->get_perfdata_for_output(label => 'critical-temperature-instance-' . $instance)
        }

        if (!$self->{output}->is_status(value => $exit2, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit2,
                short_msg => sprintf(
                    "temperature '%s' is %s degree centigrade",
                    $entry->{name},
                    $entry->{temperature}
                )
            );
        }
        $self->{output}->perfdata_add(
            nlabel => 'hardware.temperature.celsius',,
            unit => 'C',
            instances => $entry->{name},
            value => $entry->{temperature},
            warning => $warn,
            critical => $crit
        );
    }
}

1;
