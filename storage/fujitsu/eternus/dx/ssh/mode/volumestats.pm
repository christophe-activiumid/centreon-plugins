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

package storage::fujitsu::eternus::dx::ssh::mode::volumestats;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::misc;

sub prefix_volume_output {
    my ($self, %options) = @_;
    
    return "Volume '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'volume', type => 1, cb_prefix_output => 'prefix_volume_output', message_multiple => 'All Volumes are ok' }
    ];
    
    $self->{maps_counters}->{volume} = [
        { label => 'read-iops', nlabel => 'volume.io.read.usage.iops', set => {
                key_values => [ { name => 'read_iops' }, { name => 'display' } ],
                output_template => 'Read IOPS : %d',
                perfdatas => [
                    { label => 'read_iops', template => '%d',
                      unit => 'iops', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'write-iops', nlabel => 'volume.io.write.usage.iops', set => {
                key_values => [ { name => 'write_iops' }, { name => 'display' } ],
                output_template => 'Write IOPS : %d',
                perfdatas => [
                    { label => 'write_iops', template => '%d',
                      unit => 'iops', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'read-traffic', nlabel => 'volume.traffic.read.usage.bitspersecond', set => {
                key_values => [ { name => 'read_throughput' }, { name => 'display' } ],
                output_template => 'Read Traffic : %s %s/s', output_change_bytes => 2,
                perfdatas => [
                    { label => 'read_throughput', template => '%d',
                      unit => 'b/s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'write-traffic', nlabel => 'volume.traffic.write.usage.bitspersecond', set => {
                key_values => [ { name => 'write_throughput' }, { name => 'display' } ],
                output_template => 'Write Traffic : %s %s/s', output_change_bytes => 2,
                perfdatas => [
                    { label => 'write_throughput', template => '%d',
                      unit => 'b/s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'read-response-time', nlabel => 'volume.io.read.time.response.milliseconds', set => {
                key_values => [ { name => 'read_response_time' }, { name => 'display' } ],
                output_template => 'Read Response Time : %d ms',
                perfdatas => [
                    { label => 'read_response_time', template => '%d',
                      unit => 'ms', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'write-response-time', nlabel => 'volume.io.write.time.response.milliseconds', set => {
                key_values => [ { name => 'write_response_time' }, { name => 'display' } ],
                output_template => 'Write Response Time : %d ms',
                perfdatas => [
                    { label => 'write_response_time', template => '%d',
                      unit => 'ms', min => 0, label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'read-processing-time', nlabel => 'volume.io.read.time.processing.milliseconds', set => {
                key_values => [ { name => 'read_processing_time' }, { name => 'display' } ],
                output_template => 'Read Processing Time : %d ms',
                perfdatas => [
                    { label => 'read_processing_time', template => '%d',
                      unit => 'ms', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'write-processing-time', nlabel => 'volume.io.write.time.processing.milliseconds', set => {
                key_values => [ { name => 'write_processing_time' }, { name => 'display' } ],
                output_template => 'Write Processing Time : %d ms',
                perfdatas => [
                    { label => 'write_processing_time', template => '%d',
                      unit => 'ms', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'read-cache-hit-rate', nlabel => 'volume.io.read.cache.hits.percentage', set => {
                key_values => [ { name => 'read_cache_hit_rate' }, { name => 'display' } ],
                output_template => 'Read Cache Hit Rate : %d %%',
                perfdatas => [
                    { label => 'read_cache_hit_rate', template => '%d',
                      unit => '%', min => 0, max => 100, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'write-cache-hit-rate', nlabel => 'volume.io.write.cache.hits.percentage', set => {
                key_values => [ { name => 'write_cache_hit_rate' }, { name => 'display' } ],
                output_template => 'Write Cache Hit Rate : %d %%',
                perfdatas => [
                    { label => 'write_cache_hit_rate', template => '%d',
                      unit => '%', min => 0, max => 100, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
        'filter-name:s' => { name => 'filter_name' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my ($stdout) = $options{custom}->execute_command(
        command => 'show',
        command_options => "performance -type host-io\n",
        ssh_pipe => 1
    );

    #Volume                                 IOPS(IOPS)            Throughput(MB/s)      Response Time(msec.)   Processing Time(msec.)  Cache Hit Rate(%)
    #No.   Name                             Read     / Write      Read     / Write      Read     / Write       Read     / Write        Read     / Write    / Prefetch
    #----- -------------------------------- ---------- ---------- ---------- ---------- ---------- ----------  ---------- ----------   ---------- ---------- ----------
    #    1 VOL001                                 6621       5192        589        379      17055      12056       10025      10010           41         37         36
    #    2 VOL002                                 7791       6608        613        292      12148      11045       10005      10007           41         37         36
    
    $self->{volume} = {};
    my %template_label = (cache_hit_rate => { labels => ['read', 'write', 'prefetch'] });
    my @template_values = ();
    foreach (split /\n/, $stdout) {
        if (/^Volume/) {            
            while (/(\sIOPS|\sThroughput|\sResponse Time|\sProcessing Time|[^C]\sCache Hit Rate)/mgi) {
                my $value = lc(centreon::plugins::misc::trim($1));
                $value =~ s/ /_/g;
                
                my $labels = ['read', 'write'];
                if (defined($template_label{$value})) {
                    $labels = $template_label{$value}->{labels};
                }
                
                foreach (@{$labels}) {
                    push @template_values, { label => $_ . '_' . $value };
                }
            }
            next;
        }
        next if (/----|Name/i);
        next if (/^CLI>/);

        my $value = centreon::plugins::misc::trim($_);
        my @matches = split(/\s+/, $value);

        next if (!defined($matches[1]));

        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $matches[1] !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(long_msg => "Skipping  '" . $matches[1] . "': no matching filter name.", debug => 1);
            next;
        }

        my %counters = ();
        for (my $i = 0; $i < scalar(@template_values); $i++) {
            $counters{$template_values[$i]->{label}} = $matches[$i + 2];
        }
        $counters{read_throughput} *= 1000 * 1000 * 8 if (defined($counters{read_throughput}));
        $counters{write_throughput} *= 1000 * 1000 * 8 if (defined($counters{write_throughput}));
        
        $self->{volume}->{$matches[0]} = {
            display => $matches[1],
            %counters
        };
    }

    if (scalar(keys %{$self->{volume}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No volume found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check volume statistics.

Command used: show performance -type host-io

=over 8

=item B<--filter-name>

Filter by name (regexp can be used).

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'read-iops', 'write-iops', 'read-traffic', 'write-traffic',
'read-response-time', 'write-response-time', 'read-processing-time', 'write-processing-time',
'read-cache-hit-rate', 'write-cache-hit-rate'.

=back

=cut
