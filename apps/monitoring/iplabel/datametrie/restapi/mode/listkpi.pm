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

package apps::monitoring::iplabel::datametrie::restapi::mode::listkpi;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $options{options}->add_options(arguments => {
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
}

sub manage_selection {
    my ($self, %options) = @_;

    my $api_results = $options{custom}->request_api(
        endpoint => '/Get_Monitors/',
        label => 'Get_Monitors'
    );
    my $results = {};
    foreach (@$api_results) {
        $results->{$_->{MONITOR_ID}} = {
            id => $_->{MONITOR_ID},
            name => $_->{MONITOR_NAME},
            client_id => $_->{CLIENT_ID},
            status => $_->{MONITOR_STATUS}
        };
    }

    return $results;
}

sub run {
    my ($self, %options) = @_;

    my $results = $self->manage_selection(%options);
    foreach (sort {lc $a->{name} cmp lc $b->{name}} values %$results) {
        $self->{output}->output_add(
            long_msg => sprintf(
                '[name = %s][id = %s][client id = %s][status = %s]',
                $_->{name},
                $_->{id},
                $_->{client_id},
                $_->{status}
            )
        );
    }

    $self->{output}->output_add(
        severity => 'OK',
        short_msg => 'List kpi:'
    );
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
    $self->{output}->exit();
}

sub disco_format {
    my ($self, %options) = @_;

    $self->{output}->add_disco_format(elements => ['id', 'name', 'client_id', 'status']);
}

sub disco_show {
    my ($self, %options) = @_;

    my $scenarios = $self->manage_selection(%options);
    foreach (sort {lc $a->{name} cmp lc $b->{name}} values %$scenarios) {
        $self->{output}->add_disco_entry(%$_);
    }
}

1;

__END__

=head1 MODE

List KPI.

=over 8

=back

=cut
