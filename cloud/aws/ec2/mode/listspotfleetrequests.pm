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

package cloud::aws::ec2::mode::listspotfleetrequests;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {});

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{spot_fleet_requests} = $options{custom}->ec2spot_list_fleet_requests();
}

sub run {
    my ($self, %options) = @_;

    $self->manage_selection(%options);
    foreach (@{$self->{spot_fleet_requests}}) {
        $self->{output}->output_add(
            long_msg => sprintf("[id = %s][state = %s][status = %s]",
            $_->{SpotFleetRequestId}, $_->{SpotFleetRequestState}, $_->{ActivityStatus}));
    }
    
    $self->{output}->output_add(severity => 'OK',
                                short_msg => 'List spot fleet requests:');
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
    $self->{output}->exit();
}

sub disco_format {
    my ($self, %options) = @_;
    
    $self->{output}->add_disco_format(elements => ['id', 'state', 'status']);
}

sub disco_show {
    my ($self, %options) = @_;

    $self->manage_selection(%options);
    foreach (@{$self->{spot_fleet_requests}}) {
        $self->{output}->add_disco_entry(
            id      => $_->{SpotFleetRequestId},
            state   => $_->{SpotFleetRequestState},
            status  => $_->{ActivityStatus}
        );
    }
}

1;

__END__

=head1 MODE

List EC2 Spot Fleet Requests 

=over 8

=back

=cut
