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

package storage::huawei::oceanstor::restapi::mode::liststoragepools;

use base qw(centreon::plugins::mode);

use strict;
use warnings;
use storage::huawei::oceanstor::restapi::mode::resources qw($health_status $running_status $model);

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
        'filter-name:s' => { name => 'filter_name' },
    });
    
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
}

sub manage_selection {
    my ($self, %options) = @_;

    return $options{custom}->request(endpoint => '/storagepool');
}

sub run {
    my ($self, %options) = @_;

    my $result = $self->manage_selection(custom => $options{custom});
    my $data = $result->{data};

    foreach my $sp (@$data) {         
        $self->{output}->output_add(
            long_msg => sprintf(
                '[name: %s] [health status: %s] [running status: %s]',
                $sp->{'NAME'},
                $health_status->{$sp->{'HEALTHSTATUS'}},
                $running_status->{$sp->{'RUNNINGSTATUS'}}
            )
        );
    }    
    
    $self->{output}->output_add(
        severity => 'OK',
        short_msg => 'List storage pools:'
    );
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
    $self->{output}->exit();
}

sub disco_format {
    my ($self, %options) = @_;

    $self->{output}->add_disco_format(elements => ['name', 'health_status', 'running_status'],);
}

sub disco_show {
    my ($self, %options) = @_;

    my $result = $self->manage_selection(custom => $options{custom});
    my $data = $result->{data};

    foreach my $sp (@$data) {         
        $self->{output}->add_disco_entry( 
          name => $sp->{'NAME'}, 
          health_status => $health_status->{$sp->{'HEALTHSTATUS'}}, 
          running_status => $running_status->{$sp->{'RUNNINGSTATUS'}} );
    }
}

1;

__END__

=head1 MODE

List Storage pools.

=over 8

=back

=cut