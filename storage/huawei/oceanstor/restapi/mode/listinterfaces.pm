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

package storage::huawei::oceanstor::restapi::mode::listinterfaces;

use base qw(centreon::plugins::mode);

use strict;
use warnings;
use storage::huawei::oceanstor::restapi::mode::resources qw($health_status $running_status $model);

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
}

sub manage_selection {
    my ($self, %options) = @_;

    return $options{custom}->request(endpoint => '/eth_port');
}

sub run {
    my ($self, %options) = @_;

    my $result = $self->manage_selection(custom => $options{custom});
    my $data = $result->{data};

    foreach my $intf (@$data) {         
        $self->{output}->output_add(
            long_msg => sprintf(
                '[name: %s] [speed: %s] [health status: %s] [running status: %s]',
                $intf->{'LOCATION'} =~ s/(?<!%)\.+/-/rg ,
                $intf->{'SPEED'},
                $health_status->{$intf->{'HEALTHSTATUS'}},
                $running_status->{$intf->{'RUNNINGSTATUS'}}
            )
        );
    }    
    
    $self->{output}->output_add(
        severity => 'OK',
        short_msg => 'List interfaces:'
    );
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
    $self->{output}->exit();
}

sub disco_format {
    my ($self, %options) = @_;

    $self->{output}->add_disco_format(elements => ['name', 'speed', 'health_status', 'running_status'],);
}

sub disco_show {
    my ($self, %options) = @_;

    my $result = $self->manage_selection(custom => $options{custom});
    my $data = $result->{data};

    foreach my $intf (@$data) {
        next if($running_status->{$intf->{'RUNNINGSTATUS'}} eq   "Link Down"); # return only interface with link up
       
        $self->{output}->add_disco_entry( 
          name => $intf->{'LOCATION'} =~ s/(?<!%)\.+/-/rg , # replace all the dot (.) with dash
          speed => $intf->{'SPEED'},
          health_status => $health_status->{$intf->{'HEALTHSTATUS'}}, 
          running_status => $running_status->{$intf->{'RUNNINGSTATUS'}} );
    }
}

1;

__END__

=head1 MODE

List ethernet interfaces (not FC interfaces)

=over 8

=back

=cut