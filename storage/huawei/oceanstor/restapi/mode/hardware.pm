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


package storage::huawei::oceanstor::restapi::mode::hardware;
use Data::Dumper;
use base qw(centreon::plugins::templates::hardware);

use strict;
use warnings;

sub set_system {
    my ($self, %options) = @_;

    $self->{cb_hook2} = 'api_execute';

    $self->{regexp_threshold_numeric_check_section_option} = '^(?:enclosure\.temperature|disk\.temperature)$';
        
    $self->{thresholds} = {
        default => [
            ['normal', 'OK'],
            ['pre-fail', 'WARNING'],
            ['faulty', 'CRITICAL'],
            ['degraded', 'WARNING'],
            ['partially broken', 'WARNING'],
            ['invalid', 'CRITICAL']
        ]
    };
    
    $self->{components_path} = 'storage::huawei::oceanstor::restapi::mode::components';    
    $self->{components_module} = ['enclosure', 'bbu', 'psu','disk', 'expboard', 'fan', 'intfmodule'];
}

sub api_execute {
    my ($self, %options) = @_;

    $self->{subsystems} = {
        bbu => [],
        disk => [],
        enclosure => [],
        expboard => [],        
        fan => [],
        psu => [],
        intfmodule => []
    };
    
    my $result = $options{custom}->request(endpoint => '/enclosure');
    my $data = $result->{data};
    foreach my $entry (@$data){ push @{$self->{subsystems}->{enclosure}}, $entry; } 
    
    $result = $options{custom}->request(endpoint => '/backup_power');
    $data = $result->{data};
    foreach my $entry (@$data){ push @{$self->{subsystems}->{bbu}}, $entry; } 
    
    $result = $options{custom}->request(endpoint => '/disk');
    $data = $result->{data};
    foreach my $entry (@$data){ push @{$self->{subsystems}->{disk}}, $entry; } 
    
    $result = $options{custom}->request(endpoint => '/expboard');
    $data = $result->{data};
    foreach my $entry (@$data){ push @{$self->{subsystems}->{expboard}}, $entry; } 
    
    $result = $options{custom}->request(endpoint => '/fan');
    $data = $result->{data};
    foreach my $entry (@$data){ push @{$self->{subsystems}->{fan}}, $entry; } 
    
    $result = $options{custom}->request(endpoint => '/power');
    $data = $result->{data};
    foreach my $entry (@$data){ push @{$self->{subsystems}->{psu}}, $entry; }
    
    $result = $options{custom}->request(endpoint => '/intf_module');
    $data = $result->{data};
    foreach my $entry (@$data){ push @{$self->{subsystems}->{intfmodule}}, $entry; }      

}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {});

    return $self;
}

1;

__END__

=head1 MODE

Check hardware.

=over 8

=item B<--component>

Which component to check (Default: '.*').
Can be: 'bbu', 'disk', 'enclosure', 'expboard', 'fan', 'psu', 'intfmodule'.

=item B<--add-name-instance>

Add literal description for instance value (used in filter and threshold options).

=item B<--filter>

Exclude some parts (comma seperated list) (Example: --filter=psu)
Can also exclude specific instance: --filter=psu,0.0A.0

=item B<--no-component>

Return an error if no compenents are checked.
If total (with skipped) is 0. (Default: 'critical' returns).

=item B<--threshold-overload>

Set to overload default threshold values (syntax: section,[instance,]status,regexp)
It used before default thresholds (order stays).
Example: --threshold-overload='psu,CRITICAL,degraded'

=item B<--warning>

Set warning threshold for 'disk.temperature', 'enclosure.temperature' (syntax: type,regexp,threshold)
Example: --warning='enclosure.temperature,.*,40'

=item B<--critical>

Set critical threshold for 'disk.temperature', 'enclosure.temperature' (syntax: type,regexp,threshold)
Example: --critical='enclosure.temperature,.*,50'

=back

=cut
