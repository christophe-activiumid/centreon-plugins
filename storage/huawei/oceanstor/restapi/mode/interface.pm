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

package storage::huawei::oceanstor::restapi::mode::interface;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

use centreon::plugins::statefile;
use Digest::MD5 qw(md5_hex);
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);
use storage::huawei::oceanstor::restapi::mode::resources qw($health_status $running_status $model);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        'status: %s [health: %s]',
        $self->{result_values}->{running_status},
        $self->{result_values}->{health_status}
    );
}

sub custom_traffic_in_output {
    my ($self, %options) = @_;

    my ($traffic_in_value, $traffic_in_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{traffic_in}, network=>1);
    return sprintf(
        'Traffic In: %s (%.2f%%)',
        $traffic_in_value . " " . $traffic_in_unit,
        $self->{result_values}->{traffic_in_prct}
    );
}
sub custom_traffic_out_output {
    my ($self, %options) = @_;

    my ($traffic_out_value, $traffic_out_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{traffic_out}, network=>1);
    return sprintf(
        'Traffic Out: %s (%.2f%%)',
        $traffic_out_value . " " . $traffic_out_unit,
        $self->{result_values}->{traffic_out_prct}
    );
}

sub interface_long_output {
    my ($self, %options) = @_;

    return "checking interface '" . $options{instance_value}->{name} . "'";
}

sub prefix_interface_output {
    my ($self, %options) = @_;

    return "interface '" . $options{instance_value}->{name} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'intf', type => 3, cb_prefix_output => 'prefix_interface_output', cb_long_output => 'interface_long_output', indent_long_output => '    ', message_multiple => 'All interfaces are ok',
            group => [                
                { name => 'status', type => 0, skipped_code => { -10 => 1 } },
                { name => 'traffic', type => 0, skipped_code => { -10 => 1 } },
            ]
        }
    ];
    
    $self->{maps_counters}->{status} = [
        {
            label => 'status',
            type => 2,
            unknown_default => '%{health} =~ /unknown/i',
            warning_default => '%{health_status} =~ /errors/i',
            critical_default => '%{health_status} =~ /faulty|fail/i',
            set => {
                key_values => [ { name => 'running_status' }, { name => 'health_status'}, { name => 'name' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ],
    $self->{maps_counters}->{traffic} = [
       { label => 'traffic_in', nlabel => 'interface.traffic.in.bitspersecond', set => {
              key_values => [ { name => 'traffic_in' }, { name => 'traffic_in_prct' },{ name => 'speed' },],
              closure_custom_output => $self->can('custom_traffic_in_output'),
              perfdatas => [
                  { template => '%d', min => 0, max => 'speed', unit => 'b', cast_int => 1, label_extra_instance => 1 }
              ]
          }
      },
      { label => 'traffic_out', nlabel => 'interface.traffic.out.bitspersecond', set => {
              key_values => [ { name => 'traffic_out' }, { name => 'traffic_out_prct' }, { name => 'speed' },],
              closure_custom_output => $self->can('custom_traffic_out_output'),
              perfdatas => [
                  { template => '%d', min => 0, max => 'speed', unit => 'b', cast_int => 1, label_extra_instance => 1 }
              ]
          }
      }

    ];

}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 0);
    bless $self, $class;
    
    $self->{statefile} = centreon::plugins::statefile->new(%options);
    
    $options{options}->add_options(arguments => {
        'name:s' => { name => 'name' }
    });   
    
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
    
    if(!defined($self->{option_results}->{name})) {
        $self->{output}->add_option_msg(short_msg => "Need to specify --name option.");
        $self->{output}->option_exit();
    }
    
    $self->{statefile}->check_options(option_results => $self->{option_results}); 
}

sub reload_cache {
    my ($self, %options) = @_;

    my $datas = {};

    $datas->{last_timestamp} = time();
    
    my $result = $options{custom}->request(endpoint => '/eth_port');
        
    foreach my $intf (@{$result->{data}}) {
        my $ifname = $intf->{'LOCATION'} =~ s/(?<!%)\.+/-/rg ; # replace all the dot (.) with dash
        if( $ifname eq $self->{option_results}->{name} ) {
            $datas->{interface} = $intf;
        }        
    }
    
    if(!defined($datas->{interface})){
        $self->{output}->add_option_msg(short_msg => "Interface name not found.");
        $self->{output}->option_exit();
    }
    
    $self->{statefile}->write(data => $datas);
}


sub manage_selection {
    my ($self, %options) = @_;

    my $has_cache_file = $self->{statefile}->read(statefile => 'cache_oceanstor_' . $options{custom}->get_hostname()  . '_' . $options{custom}->get_port() . '_interface_' . $self->{option_results}->{name});

    if ($has_cache_file == 0 ) {
        $self->reload_cache(%options);
        $self->{statefile}->read();
    }

    $self->{intf} = {};
    my $cache = $self->{statefile}->get(name => 'interface');
    my $last_timestamp = $self->{statefile}->get(name => 'last_timestamp');

    my $result = $options{custom}->request(endpoint => '/eth_port/' . $cache->{'ID'});
    my $intf = $result->{data};

    my $ifname = $intf->{'LOCATION'} =~ s/(?<!%)\.+/-/rg ; # replace all the dot (.) with dash
    if ($self->{option_results}->{name} ne $ifname) {
        $self->{output}->add_option_msg(short_msg => "Interface name does not match the cache, try reloading the cache.");
        $self->{output}->option_exit();
    }
    
    #updating cache file with new data
    my $datas = {};                         
    $datas->{last_timestamp} = time();
    $datas->{interface} = $intf;
    $self->{statefile}->write(data => $datas);
    
    my $diff= $datas->{last_timestamp} -  $last_timestamp;
    
    if ($diff == 0) {
        $self->{output}->add_option_msg(short_msg => "Buffer in creation.");
        $self->{output}->option_exit();
    }
    
    my $traffic_in = ($intf->{'totalReceivedBytes'} - $cache->{'totalReceivedBytes'})*8 / $diff;  # value in Bytes, not bit
    my $traffic_out = ($intf->{'totalTransmittedBytes'} - $cache->{'totalTransmittedBytes'})*8 / $diff; 
    my $speed = $intf->{'SPEED'} * 1024 * 1024; #current negociated speed, 25000 for 25GE, 10000 for 10GE, so it's in Mb/s
    
    $self->{intf}->{ $ifname } = {
        name => $ifname,
        traffic => {
            traffic_in       => $traffic_in,
            traffic_out      => $traffic_out,
            traffic_in_prct  => $traffic_in * 100 / $speed,
            traffic_out_prct => $traffic_out * 100 / $speed,
            speed            => $speed
        },        
        status => {
            running_status => $running_status->{$intf->{'RUNNINGSTATUS'}},
            health_status  =>  $health_status->{$intf->{'HEALTHSTATUS'}},
            name           => $ifname
        },
    } 
}

1;

__END__

=head1 MODE

Check Ethernet Interface traffic usage

=over 8

=item B<--name>

Name of the interface, can be found with mode --list-interfaces

=back

=cut