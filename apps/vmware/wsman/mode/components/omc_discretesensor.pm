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

package apps::vmware::wsman::mode::components::omc_discretesensor;

use strict;
use warnings;
use apps::vmware::wsman::mode::components::resources qw($mapping_EnableState);

sub load {}

sub check {
    my ($self) = @_;
    
    my $result = $self->{wsman}->request(uri => 'http://schema.omc-project.org/wbem/wscim/1/cim-schema/2/OMC_DiscreteSensor', dont_quit => 1);
    
    $self->{output}->output_add(long_msg => "Checking OMC discrete sensors");
    $self->{components}->{omc_discretesensor} = {name => 'omc discrete sensors', total => 0, skip => 0};
    return if ($self->check_filter(section => 'omc_discretesensor') || !defined($result));

    foreach (@{$result}) {
        my $instance = $_->{Name};
        
        next if ($self->check_filter(section => 'omc_discretesensor', instance => $instance));
        if (defined($mapping_EnableState->{$_->{EnabledState}}) && $mapping_EnableState->{$_->{EnabledState}} !~ /enabled/i) {
            $self->{output}->output_add(long_msg => sprintf("skipping discrete sensor '%s' : not enabled", $_->{Name}), debug => 1);
            next;
        }
        my $status = $self->get_status(entry => $_);
        if (!defined($status)) {
            $self->{output}->output_add(long_msg => sprintf("skipping discrete sensor '%s' : no status", $_->{Name}), debug => 1);
            next;
        }
        
        $self->{components}->{omc_discretesensor}->{total}++;

        $self->{output}->output_add(long_msg => sprintf("Discrete sensor '%s' status is '%s' [instance: %s].",
                                    $_->{Name}, $status,
                                    $instance
                                    ));
        my $exit = $self->get_severity(section => 'omc_discretesensor', label => 'default', value => $status);
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(severity =>  $exit,
                                        short_msg => sprintf("Discrete sensor '%s' status is '%s'",
                                                             $_->{Name}, $status));
        }
    }
}

1;
