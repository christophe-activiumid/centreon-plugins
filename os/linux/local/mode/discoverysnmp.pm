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

package os::linux::local::mode::discoverysnmp;

use base qw(centreon::plugins::mode);

use strict;
use warnings;
use os::linux::local::mode::resources::discovery qw($discovery_match);
use centreon::plugins::snmp;
use NetAddr::IP;
use JSON::XS;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
        'subnet:s'          => { name => 'subnet' },
        'snmp-port:s'       => { name => 'snmp_port', default => 161 },
        'snmp-version:s@'   => { name => 'snmp_version' },
        'snmp-community:s@' => { name => 'snmp_community' },
        'snmp-timeout:s'    => { name => 'snmp_timeout', default => 1 },
        'prettify'          => { name => 'prettify' },
        'extra-oids:s'      => { name => 'extra_oids' }
    });

    $self->{snmp} = centreon::plugins::snmp->new(%options, noptions => 1);

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);

    if (!defined($self->{option_results}->{subnet}) ||
        $self->{option_results}->{subnet} !~ /(\d+)\.(\d+)\.(\d+)\.(\d+)\/(\d+)/) {
        $self->{output}->add_option_msg(short_msg => "Need to specify --subnet option (<ip>/<cidr>).");
        $self->{output}->option_exit();
    }
    if (!defined($self->{option_results}->{snmp_community}) || $self->{option_results}->{snmp_community} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --snmp-community option.");
        $self->{output}->option_exit();
    }
    if (!defined($self->{option_results}->{snmp_version}) || $self->{option_results}->{snmp_version} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --snmp-version option.");
        $self->{output}->option_exit();
    }
    if (!defined($self->{option_results}->{snmp_timeout}) || $self->{option_results}->{snmp_timeout} !~ /(\d+)/) {
        $self->{output}->add_option_msg(short_msg => "Need to specify --snmp-timeout option.");
        $self->{output}->option_exit();
    }

    $self->{snmp}->set_snmp_connect_params(Timeout => $self->{option_results}->{snmp_timeout} * (10**6));
    $self->{snmp}->set_snmp_connect_params(Retries => 0);
    $self->{snmp}->set_snmp_params(subsetleef => 1);
    $self->{snmp}->set_snmp_params(snmp_autoreduce => 0);
    $self->{snmp}->set_snmp_params(snmp_errors_exit => 'unknown');

    $self->{oid_sysDescr} = '.1.3.6.1.2.1.1.1.0';
    $self->{oid_sysName} = '.1.3.6.1.2.1.1.5.0';

    $self->{oids} = [$self->{oid_sysDescr}, $self->{oid_sysName}];
    $self->{extra_oids} = {};
    if (defined($self->{option_results}->{extra_oids})) {
        my @extra_oids = split(/,/, $self->{option_results}->{extra_oids});
        foreach my $extra_oid (@extra_oids) {
            next if ($extra_oid eq '');

            my @values = split(/=/, $extra_oid);
            my ($name, $oid) = ('', $values[0]);
            if (defined($values[1])) {
                $name = $values[0];
                $oid = $values[1];
            }

            $oid =~ s/^(\d+)/\.$1/;
            $self->{extra_oids}->{$oid} = $name;
            push @{$self->{oids}}, $oid;
        }
    }
}

sub define_type {
    my ($self, %options) = @_;

    return 'unknown' unless (defined($options{desc}) && $options{desc} ne '');
    foreach (@$discovery_match) {
        if ($options{desc} =~ /$_->{re}/) {
            return $_->{type};
        }
    }

    return 'unknown';
}

sub snmp_request {
    my ($self, %options) = @_;

    $self->{snmp}->set_snmp_connect_params(DestHost => $options{ip});
    $self->{snmp}->set_snmp_connect_params(Community => $options{community});
    $self->{snmp}->set_snmp_connect_params(Version => $options{version});
    $self->{snmp}->set_snmp_connect_params(RemotePort => $options{port});
    return undef if ($self->{snmp}->connect(dont_quit => 1) != 0);
    return $self->{snmp}->get_leef(
        oids => $self->{oids},
        nothing_quit => 0, dont_quit => 1
    );
}

sub run {
    my ($self, %options) = @_;

    my @disco_data;
    my $disco_stats;
    
    my $last_version;
    my $last_community;
    my $subnet = NetAddr::IP->new($self->{option_results}->{subnet});

    $disco_stats->{start_time} = time();

    foreach my $ip (@{$subnet->splitref($subnet->bits())}) {
        my $result;
        foreach my $community (@{$self->{option_results}->{snmp_community}}) {
            foreach my $version (@{$self->{option_results}->{snmp_version}}) {
                $result = $self->snmp_request(
                    ip => $ip->addr,
                    community => $community,
                    version => $version,
                    port => $self->{option_results}->{snmp_port}
                );
                $last_version = $version;
                $last_community = $community;
                last if (defined($result));
            }
        }
        next if (!defined($result) || $result eq '');

        my %host;
        $host{type} = $self->define_type(desc => $result->{$self->{oid_sysDescr}});
        $host{desc} = $result->{$self->{oid_sysDescr}};
        $host{desc} =~ s/\n/ /g if (defined($host{desc}));
        $host{ip} = $ip->addr;
        $host{hostname} = $result->{$self->{oid_sysName}};
        $host{snmp_version} = $last_version;
        $host{snmp_community} = $last_community;
        $host{snmp_port} = $self->{option_results}->{snmp_port};
        $host{extra_oids} = [];
        foreach (keys %{$self->{extra_oids}}) {
            my $label = defined($self->{extra_oids}->{$_}) && $self->{extra_oids}->{$_} ne '' ? $self->{extra_oids}->{$_} : $_;
            my $value = defined($result->{$_}) ? $result->{$_} : 'unknown';
            push @{$host{extra_oids}}, { oid => $label, value => $value };
        }

        push @disco_data, \%host;
    }
    
    $disco_stats->{end_time} = time();
    $disco_stats->{duration} = $disco_stats->{end_time} - $disco_stats->{start_time};
    $disco_stats->{discovered_items} = @disco_data;
    $disco_stats->{results} = \@disco_data;

    my $encoded_data;
    eval {
        if (defined($self->{option_results}->{prettify})) {
            $encoded_data = JSON::XS->new->utf8->pretty->encode($disco_stats);
        } else {
            $encoded_data = JSON::XS->new->utf8->encode($disco_stats);
        }
    };
    if ($@) {
        $encoded_data = '{"code":"encode_error","message":"Cannot encode discovered data into JSON format"}';
    }
    
    $self->{output}->output_add(short_msg => $encoded_data);
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1);
    $self->{output}->exit();
}
    
1;

__END__

=head1 MODE

Resources discovery.

=over 8

=item B<--subnet>

Specify subnet from which discover
resources (Must be <ip>/<cidr> format) (Mandatory).

=item B<--snmp-port>

Specify SNMP port (Default: 161).

=item B<--snmp-version>

Specify SNMP version (Can be multiple) (Mandatory).

=item B<--snmp-community>

Specify SNMP community (Can be multiple) (Mandatory).

=item B<--snmp-timeout>

Specify SNMP timeout in second (Default: 1).

=item B<--prettify>

Prettify JSON output.

=item B<--extra-oids>

Specify extra OIDs to get (Eg: --extra-oids='hrSystemInitialLoadParameters=1.3.6.1.2.1.25.1.4.0,sysDescr=.1.3.6.1.2.1.1.1.0').

=back

=cut
