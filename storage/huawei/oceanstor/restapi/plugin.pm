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

package storage::huawei::oceanstor::restapi::plugin;

use strict;
use warnings;
use base qw(centreon::plugins::script_custom);

sub new {
    my ($class, %options) = @_;

    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $self->{version} = '1.0';
    $self->{modes} = {
        'system'            => 'storage::huawei::oceanstor::restapi::mode::system',
        'hardware'          => 'storage::huawei::oceanstor::restapi::mode::hardware',        
        'list-controllers'  => 'storage::huawei::oceanstor::restapi::mode::listcontrollers',
        'controllers'       => 'storage::huawei::oceanstor::restapi::mode::controllers',
        'list-storagepools' => 'storage::huawei::oceanstor::restapi::mode::liststoragepools',
        'storagepools'      => 'storage::huawei::oceanstor::restapi::mode::storagepools',
        'diskdomains'       => 'storage::huawei::oceanstor::restapi::mode::diskdomains',
        'list-luns'         => 'storage::huawei::oceanstor::restapi::mode::listluns',
        'luns'              => 'storage::huawei::oceanstor::restapi::mode::luns',
        #'alarms'            => 'storage::huawei::oceanstor::restapi::mode::alarms',
        'list-interfaces'   => 'storage::huawei::oceanstor::restapi::mode::listinterfaces',
        'interface'         => 'storage::huawei::oceanstor::restapi::mode::interface'
    };

    $self->{custom_modes}->{api} = 'storage::huawei::oceanstor::restapi::custom::api';
    return $self;
}

1;

__END__

=head1 PLUGIN DESCRIPTION

Check Huawei Dordado OceanStor/OceanProtect SAN using Rest API.

=cut