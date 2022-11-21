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
# Authors : Roman Morandell - ivertix
#

package storage::huawei::oceanstor::restapi::custom::api; 
#use Data::Dumper;


use strict;
use warnings;
use centreon::plugins::http;
use centreon::plugins::statefile;
use JSON::XS;
use Digest::MD5 qw(md5_hex);

sub new {
    my ($class, %options) = @_;
    my $self = {};
    bless $self, $class;

    if (!defined($options{output})) {
        print "Class Custom: Need to specify 'output' argument.\n";
        exit 3;
    }
    if (!defined($options{options})) {
        $options{output}->add_option_msg(short_msg => "Class Custom: Need to specify 'options' argument.");
        $options{output}->option_exit();
    }

    if (!defined($options{noptions})) {
        $options{options}->add_options(arguments => {
            'hostname:s'     => { name => 'hostname' },
            'port:s'         => { name => 'port' },
            'proto:s'        => { name => 'proto' },
            'url-path:s'     => { name => 'url_path' },
            'api-username:s' => { name => 'api_username' },
            'api-password:s' => { name => 'api_password' },
            'timeout:s'      => { name => 'timeout' }
        });
    }
    $options{options}->add_help(package => __PACKAGE__, sections => 'REST API OPTIONS', once => 1);

    $self->{output} = $options{output};
    $self->{http} = centreon::plugins::http->new(%options);
    $self->{cache} = centreon::plugins::statefile->new(%options);

    return $self;
}

sub set_options {
    my ($self, %options) = @_;

    $self->{option_results} = $options{option_results};
}

sub set_defaults {}

sub check_options {
    my ($self, %options) = @_;

    $self->{hostname} = (defined($self->{option_results}->{hostname})) ? $self->{option_results}->{hostname} : '';
    $self->{proto} = (defined($self->{option_results}->{proto})) ? $self->{option_results}->{proto} : 'https';
    $self->{port} = (defined($self->{option_results}->{port})) ? $self->{option_results}->{port} : 8088;
    $self->{url_path} = (defined($self->{option_results}->{url_path})) ? $self->{option_results}->{url_path} : '/deviceManager/rest';
    $self->{api_username} = (defined($self->{option_results}->{api_username})) ? $self->{option_results}->{api_username} : '';
    $self->{api_password} = (defined($self->{option_results}->{api_password})) ? $self->{option_results}->{api_password} : '';
    $self->{api_scope} = (defined($self->{option_results}->{api_scope})) ? $self->{option_results}->{api_scope} : '0';
    $self->{timeout} = (defined($self->{option_results}->{timeout})) ? $self->{option_results}->{timeout} : 30;    
    $self->{unknown_http_status} = (defined($self->{option_results}->{unknown_http_status})) ? $self->{option_results}->{unknown_http_status} : '%{http_code} < 200 or %{http_code} >= 300' ;
    $self->{warning_http_status} = (defined($self->{option_results}->{warning_http_status})) ? $self->{option_results}->{warning_http_status} : '';
    $self->{critical_http_status} = (defined($self->{option_results}->{critical_http_status})) ? $self->{option_results}->{critical_http_status} : '';

    if ($self->{hostname} eq '') {
        $self->{output}->add_option_msg(short_msg => 'Need to specify hostname option.');
        $self->{output}->option_exit();
    }
    if ($self->{api_username} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --api-username option.");
        $self->{output}->option_exit();
    }
    if ($self->{api_password} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --api-password option.");
        $self->{output}->option_exit();
    }

    $self->{cache}->check_options(option_results => $self->{option_results});
    return 0;
}

sub get_connection_infos {
    my ($self, %options) = @_;

    return $self->{hostname} . '_' . $self->{http}->get_port();
}

sub get_hostname {
    my ($self, %options) = @_;

    return $self->{hostname};
}

sub get_port {
    my ($self, %options) = @_;

    return $self->{port};
}

sub json_decode {
    my ($self, %options) = @_;

    $options{content} =~ s/\r//mg;
    my $decoded;
    eval {
        $decoded = JSON::XS->new->utf8->decode($options{content});
    };
    if ($@) {
        $self->{output}->add_option_msg(short_msg => "Cannot decode json response: $@");
        $self->{output}->option_exit();
    }

    return $decoded;
}

sub build_options_for_httplib {
    my ($self, %options) = @_;

    $self->{option_results}->{hostname} = $self->{hostname};
    $self->{option_results}->{port} = $self->{port};
    $self->{option_results}->{proto} = $self->{proto};
}

sub settings {
    my ($self, %options) = @_;

    $self->build_options_for_httplib();
    $self->{http}->add_header(key => 'Accept', value => 'application/json');
    $self->{http}->set_options(%{$self->{option_results}});
}

sub clean_session {
    my ($self, %options) = @_;

    my $datas = {};
    $options{statefile}->write(data => $datas);
    $self->{cookie_session} = undef;
}

sub get_session {
    my ($self, %options) = @_;

    my $has_cache_file = $options{statefile}->read(statefile => 'oceanstor_' . md5_hex($self->{option_results}->{hostname}) . '_' . md5_hex($self->{option_results}->{api_username}));
    my $cookie_session = $options{statefile}->get(name => 'cookie_session');
    my $iBaseToken = $options{statefile}->get(name => 'iBaseToken');
    my $deviceid = $options{statefile}->get(name => 'deviceid');

    my $json_request = { username => $self->{api_username}, password => $self->{api_password}, scope => $self->{api_scope} };
    my $encoded;
        eval {
            $encoded = encode_json($json_request);
        };
        if ($@) {
            $self->{output}->add_option_msg(short_msg => 'cannot encode json request');
            $self->{output}->option_exit();
        }
    
    if ($has_cache_file == 0 || !defined($cookie_session) || !defined($iBaseToken)|| !defined($deviceid)) {
        my ($content) = $self->{http}->request(
            method => 'POST',
            url_path => '/deviceManager/rest/xxxxx/sessions',
            header => ['Content-type: application/json'],
            query_form_post => $encoded,
            cookies_file => '',
            warning_status => '', unknown_status => '', critical_status => ''
        );

        if ($self->{http}->get_code() != 200) {
            $self->{output}->add_option_msg(short_msg => "Authentication error [code: '" . $self->{http}->get_code() . "'] [message: '" . $self->{http}->get_message() . "']");
            $self->{output}->option_exit();
        }

        my $decoded;
        eval {
            $decoded = JSON::XS->new->utf8->decode($content);
        };
        if ($@) {
            $self->{output}->add_option_msg(short_msg => "Cannot decode json response");
            $self->{output}->option_exit();
        }

        my $errorcode=$decoded->{error}->{code};
        my $errordesc=$decoded->{error}->{description};
        if($errorcode != 0){
            $self->{output}->add_option_msg(short_msg => "Login Error : " . $errordesc);
            $self->{output}->option_exit();        
        }
        
        my (@cookies) = $self->{http}->get_first_header(name => 'Set-Cookie');
        foreach my $cookie (@cookies) {
            $cookie_session = $1 if ($cookie =~ /session=(.+?);/);
        }

        if (!defined($cookie_session)) {
            $self->{output}->add_option_msg(short_msg => "Cannot get cookie");
            $self->{output}->option_exit();
        }

        $deviceid=$decoded->{data}->{deviceid};
        $iBaseToken = $decoded->{data}->{iBaseToken};
        
        my $datas = {
            updated => time(),
            iBaseToken => $iBaseToken,
            deviceid => $deviceid,
            cookie_session => $cookie_session
        };

        $options{statefile}->write(data => $datas);
    }
    
    $self->{cookie_session} = $cookie_session;
    $self->{iBaseToken} = $iBaseToken;
    $self->{deviceid} = $deviceid;

}

sub request {
    my ($self, %options) = @_;

    $self->settings();
   
    if (!defined($self->{deviceid}) || !defined($self->{cookie_session})) {
        $self->get_session(statefile => $self->{cache});
    }

    my $endpoint = $self->{url_path} . "/" . $self->{deviceid} . $options{endpoint};

    my $content = $self->{http}->request(
        method => 'GET',
        url_path => $endpoint,
        get_param => $options{get_param},
        header => [
            'Cookie: session=' . $self->{cookie_session},
            'iBaseToken: ' . $self->{iBaseToken},
            'Content-Type: application/json'
        ],
        warning_status => '',
        unknown_status => '',
        critical_status => ''
    );


    if ($self->{http}->get_code() < 200 || $self->{http}->get_code() >= 300) {
        $self->{output}->add_option_msg(short_msg => 'Error connecting to storage API, http code: ' . $self->{http}->get_code());
        $self->{output}->option_exit();    
    }
 
    my $decoded = $self->json_decode(content => $content);
    if (!defined($decoded)) {
        $self->{output}->add_option_msg(short_msg => 'Error while retrieving data (add --debug option for detailed message)');
        $self->{output}->option_exit();
    }
    
    # additionnal retry because even with auth failure httpcode is always 200, and the errorcode is "-401" is in the payload.
    my $errorcode=$decoded->{error}->{code};
    if ($errorcode != 0) {
        $self->clean_session(statefile => $self->{cache});
        $self->get_session(statefile => $self->{cache});
        $content = $self->{http}->request(
          method => 'GET',
          url_path => $endpoint,
          get_param => $options{get_param},
          header => [
              'Cookie: session=' . $self->{cookie_session},
              'iBaseToken: ' . $self->{iBaseToken},
              'Content-Type: application/json'
          ],
          warning_status => '',
          unknown_status => '',
          critical_status => ''
      );
    }

    $decoded = $self->json_decode(content => $content);
    if (!defined($decoded)) {
        $self->{output}->add_option_msg(short_msg => 'Error while retrieving data (add --debug option for detailed message)');
        $self->{output}->option_exit();
    }
    $errorcode=$decoded->{error}->{code};
    my $errordesc=$decoded->{error}->{description};
    if ($errorcode != 0) {
        $self->{output}->add_option_msg(short_msg => 'Error while retrieving data error code: ' . $errorcode . ' Message: ' . $errordesc);
        $self->{output}->option_exit();
    }
    return $decoded;
}

1;

__END__

=head1 NAME

OceanStor 6.x API

=head1 SYNOPSIS

Oceanstor api

=head1 REST API OPTIONS

=over 8

=item B<--hostname>

API hostname.

=item B<--url-path>

API url path (Default: '/deviceManager/rest')

=item B<--port>

API port (Default: 8088)

=item B<--proto>

Specify https if needed (Default: 'https')

=item B<--api-username>

Set API username

=item B<--api-password>

Set API password

=item B<--api-password>

Set API scope '0':local '1':ldap (Default: '0')

=item B<--timeout>

Set HTTP timeout

=back

=head1 DESCRIPTION

B<custom>.

=cut