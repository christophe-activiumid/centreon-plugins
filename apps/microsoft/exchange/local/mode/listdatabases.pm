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

package apps::microsoft::exchange::local::mode::listdatabases;

use base qw(centreon::plugins::mode);

use strict;
use warnings;
use centreon::plugins::misc;
use centreon::common::powershell::exchange::listdatabases;
use JSON::XS;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'remote-host:s'     => { name => 'remote_host' },
        'remote-user:s'     => { name => 'remote_user' },
        'remote-password:s' => { name => 'remote_password' },
        'no-ps'             => { name => 'no_ps' },
        'timeout:s'         => { name => 'timeout', default => 50 },
        'command:s'         => { name => 'command' },
        'command-path:s'    => { name => 'command_path' },
        'command-options:s'    => { name => 'command_options' },
        'ps-exec-only'         => { name => 'ps_exec_only' },
        'ps-display'           => { name => 'ps_display' },
        'ps-database-filter:s' => { name => 'ps_database_filter' }
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);

    centreon::plugins::misc::check_security_command(
        output => $self->{output},
        command => $self->{option_results}->{command},
        command_options => $self->{option_results}->{command_options},
        command_path => $self->{option_results}->{command_path}
    );

    $self->{option_results}->{command} = 'powershell.exe'
        if (!defined($self->{option_results}->{command}) || $self->{option_results}->{command} eq '');
    $self->{option_results}->{command_options} = '-InputFormat none -NoLogo -EncodedCommand'
        if (!defined($self->{option_results}->{command_options}) || $self->{option_results}->{command_options} eq '');
}

sub manage_selection {
    my ($self, %options) = @_;

    my $decoded;
    eval {
        $decoded = JSON::XS->new->decode($options{stdout});
    };
    if ($@) {
        $self->{output}->add_option_msg(short_msg => "Cannot decode json response: $@");
        $self->{output}->option_exit();
    }
    return $decoded;
}

sub run {
    my ($self, %options) = @_;

    if (!defined($self->{option_results}->{no_ps})) {
        my $ps = centreon::common::powershell::exchange::listdatabases::get_powershell(
            remote_host => $self->{option_results}->{remote_host},
            remote_user => $self->{option_results}->{remote_user},
            remote_password => $self->{option_results}->{remote_password},
            filter_database => $self->{option_results}->{ps_database_filter}
        );
        if (defined($self->{option_results}->{ps_display})) {
            $self->{output}->output_add(
                severity => 'OK',
                short_msg => $ps
            );
            $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
            $self->{output}->exit();
        }

        $self->{option_results}->{command_options} .= " " . centreon::plugins::misc::powershell_encoded($ps);
    }

    my ($stdout) = centreon::plugins::misc::execute(
        output => $self->{output},
        options => $self->{option_results},
        command => $self->{option_results}->{command},
        command_path => $self->{option_results}->{command_path},
        command_options => $self->{option_results}->{command_options}
    );
    if (defined($self->{option_results}->{ps_exec_only})) {
        $self->{output}->output_add(
            severity => 'OK',
            short_msg => $stdout
        );
    } else {
        $self->{output}->output_add(
            severity => 'OK',
            short_msg => 'List databases:'
        );

        my $decoded = $self->manage_selection(stdout => $stdout);
        foreach my $db (@$decoded) {
            $self->{output}->output_add(
                long_msg => sprintf(
                    "[name: %s][server: %s][mounted: %s]",
                    $db->{name},
                    $db->{server},
                    $db->{mounted} =~ /True|1/i ? 'true' : 'false'
                )
            );
        }
    }
    
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
    $self->{output}->exit();
}

sub disco_format {
    my ($self, %options) = @_;

    $self->{output}->add_disco_format(elements => ['name', 'server', 'mounted']);
}

sub disco_show {
    my ($self, %options) = @_;

    if (!defined($self->{option_results}->{no_ps})) {
        my $ps = centreon::common::powershell::exchange::listdatabases::get_powershell(
            remote_host => $self->{option_results}->{remote_host},
            remote_user => $self->{option_results}->{remote_user},
            remote_password => $self->{option_results}->{remote_password},
            filter_database => $self->{option_results}->{ps_database_filter}
        );
        $self->{option_results}->{command_options} .= " " . centreon::plugins::misc::powershell_encoded($ps);
    }

    my ($stdout) = centreon::plugins::misc::execute(
        output => $self->{output},
        options => $self->{option_results},
        command => $self->{option_results}->{command},
        command_path => $self->{option_results}->{command_path},
        command_options => $self->{option_results}->{command_options}
    );

    my $decoded = $self->manage_selection(stdout => $stdout);

    foreach my $db (@$decoded) {
        $self->{output}->add_disco_entry(
            name => $db->{name},
            server => $db->{server},
            mounted => $db->{mounted} =~ /True|1/i ? 'true' : 'false'
        );
    }
}

1;

__END__

=head1 MODE

List Exchange databases.

=over 8

=item B<--remote-host>

Open a session to the remote-host (fully qualified host name). --remote-user and --remote-password are optional

=item B<--remote-user>

Open a session to the remote-host with authentication. This also needs --remote-host and --remote-password.

=item B<--remote-password>

Open a session to the remote-host with authentication. This also needs --remote-user and --remote-host.

=item B<--timeout>

Set timeout time for command execution (Default: 50 sec)

=item B<--no-ps>

Don't encode powershell. To be used with --command and 'type' command.

=item B<--command>

Command to get information (Default: 'powershell.exe').
Can be changed if you have output in a file. To be used with --no-ps option!!!

=item B<--command-path>

Command path (Default: none).

=item B<--command-options>

Command options (Default: '-InputFormat none -NoLogo -EncodedCommand').

=item B<--ps-display>

Display powershell script.

=item B<--ps-exec-only>

Print powershell output.

=item B<--ps-database-filter>

Filter database (only wilcard '*' can be used. In Powershell).

=back

=cut
