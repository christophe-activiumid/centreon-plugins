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

package storage::huawei::oceanstor::restapi::mode::components::intfmodule;

use strict;
use warnings;
use storage::huawei::oceanstor::restapi::mode::resources qw($health_status $running_status $model);


sub load {}

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking interface module');
    $self->{components}->{intfmodule} = { name => 'intfmodule', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'intfmodule'));

    foreach my $entry (@{$self->{subsystems}->{intfmodule}}) {
        my $instance = $entry->{'ID'};
        my $name = $entry->{'LOCATION'} . ':' . $entry->{'NAME'};

        next if ($self->check_filter(section => 'intfmodule', instance => $instance, name => $name));
        
        $self->{components}->{intfmodule}->{total}++;
        $self->{output}->output_add(
            long_msg => sprintf(
                "interface module instance '%s' status is '%s' [model: %s location: %s, running status: %s]",
                $instance,
                $health_status->{$entry->{'HEALTHSTATUS'}},
                $model->{$entry->{'MODEL'}},                                
                $entry->{'LOCATION'},
                $running_status->{$entry->{'RUNNINGSTATUS'}}
            )
        );
        my $exit = $self->get_severity(label => 'default', section => 'intfmodule', name => $name, value => $health_status->{$entry->{'HEALTHSTATUS'}});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf(
                    "Interface module '%s' status is '%s'",
                    $instance,
                    $health_status->{$entry->{'HEALTHSTATUS'}}
                )
            );
        }
    }
}

1;