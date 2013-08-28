#!/usr/bin/perl -w
############################## check_snmp_cpfw ##############
# Version : 0.7
# Date : Oct 02 2004
# Author  : Patrick Proy (patrick at proy.org)
# Help : http://www.manubulon.com/nagios/
# Licence : GPL - http://www.fsf.org/licenses/gpl.txt
# TODO :
# - check sync method
#################################################################
#
# Help : ./check_snmp_cpfw.pl -h
#

use strict;
use Getopt::Long;

# Nagios specific
require "@NAGIOS_PLUGINS@/Centreon/SNMP/Utils.pm";

use lib "@NAGIOS_PLUGINS@";
use utils qw(%ERRORS);

#my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
my %OPTION = (
    "host" => undef,
    "snmp-community" => "public", "snmp-version" => 1, "snmp-port" => 161, 
    "snmp-auth-key" => undef, "snmp-auth-user" => undef, "snmp-auth-password" => undef, "snmp-auth-protocol" => "MD5",
    "snmp-priv-key" => undef, "snmp-priv-password" => undef, "snmp-priv-protocol" => "DES",
    "maxrepetitions" => undef, "snmptimeout" => undef,
    "64-bits" => undef,
);
my $session_params;

########### SNMP Datas ###########

###### FW data
my $policy_state	= "1.3.6.1.4.1.2620.1.1.1.0"; # "Installed"
my $policy_name		= "1.3.6.1.4.1.2620.1.1.2.0"; # Installed policy name
my $connections		= "1.3.6.1.4.1.2620.1.1.25.3.0"; # number of connections
#my $connections_peak	= "1.3.6.1.4.1.2620.1.1.25.4.0"; # peak number of connections
my @fw_checks 		= ($policy_state,$policy_name,$connections);

###### SVN data
my $svn_status		= "1.3.6.1.4.1.2620.1.6.102.0"; # "OK" svn status
my %svn_checks		= ($svn_status,"OK");
my %svn_checks_n	= ($svn_status,"SVN status");
my @svn_checks_oid	= ($svn_status);

###### HA data

my $ha_active		= "1.3.6.1.4.1.2620.1.5.5.0"; 	# "yes"
my $ha_state		= "1.3.6.1.4.1.2620.1.5.6.0"; 	# "active"
my $ha_block_state	= "1.3.6.1.4.1.2620.1.5.7.0"; 	#"OK" : ha blocking state
my $ha_status		= "1.3.6.1.4.1.2620.1.5.102.0"; # "OK" : ha status

my %ha_checks		=( $ha_active,"yes",$ha_state,"active",$ha_block_state,"OK",$ha_status,"OK");
my %ha_checks_n		=( $ha_active,"HA active",$ha_state,"HA state",$ha_block_state,"HA block state",$ha_status,"ha_status");
my @ha_checks_oid	=( $ha_active,$ha_state,$ha_block_state,$ha_status);

my $ha_mode		= "1.3.6.1.4.1.2620.1.5.11.0";  # "Sync only" : ha Working mode

my $ha_tables		= "1.3.6.1.4.1.2620.1.5.13.1"; 	# ha status table
my $ha_tables_index	= ".1";
my $ha_tables_name	= ".2";
my $ha_tables_state	= ".3"; # "OK"
my $ha_tables_prbdesc	= ".6"; # Description if state is != "OK"

#my @ha_table_check	= ("Synchronization","Filter","cphad","fwd"); # process to check

####### MGMT data

my $mgmt_status		= "1.3.6.1.4.1.2620.1.7.5.0";	# "active" : management status
my $mgmt_alive		= "1.3.6.1.4.1.2620.1.7.6.0";   # 1 : management is alive if 1
my $mgmt_stat_desc	= "1.3.6.1.4.1.2620.1.7.102.0"; # Management status description
my $mgmt_stats_desc_l	= "1.3.6.1.4.1.2620.1.7.103.0"; # Management status long description

my %mgmt_checks		= ($mgmt_status,"active",$mgmt_alive,"1");
my %mgmt_checks_n	= ($mgmt_status,"Mgmt status",$mgmt_alive,"Mgmt alive");
my @mgmt_checks_oid	= ($mgmt_status,$mgmt_alive);

#################################### Globals ##############################""

my $Version='0.7';

my $o_help=	undef; 		# wan't some help ?
my $o_verb=	undef;		# verbose mode
my $o_version=	undef;		# print version
my $o_warn=	undef;		# Warning for connections
my $o_crit=	undef;		# Crit for connections
my $o_svn=	undef;		# Check for SVN status
my $o_fw=	undef;		# Check for FW status
my $o_ha=	undef;		# Check for HA status
my $o_mgmt=	undef;		# Check for management status
my $o_policy=	undef;		# Check for policy name
my $o_conn=	undef;		# Check for connexions
my $o_perf=	undef;		# Performance data output


# functions

sub p_version { print "check_snmp_cpfw version : $Version\n"; }

sub print_usage {
    print "Usage: $0 [-v] -H <host> -C <snmp_community> | (-l login -x passwd) [-s] [-w [-p=pol_name] [-c=warn,crit]] [-m] [-a] [-f] [-p <port>] [-t <timeout>] [-V]\n";
}

sub isnnum { # Return true if arg is not a number
    my $num = shift;
    if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 0 ;}
    return 1;
}

sub help {
   print "\nSNMP Checkpoint FW-1 Monitor for Nagios version ",$Version,"\n";
   print "(c)2004 - to my cat Ratoune\n\n";
   print_usage();
   print <<EOT;
-v, --verbose
   print extra debugging information (including interface list on the system)
-h, --help
   print this help message
-H, --hostname=HOST
   name or IP address of host to check
-C, --community=COMMUNITY NAME
   community name for the host's SNMP agent (implies v1 protocol)
-s, --svn
   check for svn status
-w, --fw
   check for fw status
-a, --ha
   check for ha status
-m, --mgmt
   check for management status
-p, --policy=POLICY_NAME
   check if installed policy is POLICY_NAME (must have -w)
-c, --connexions=WARN,CRIT
   check warn and critical number of connexions (must have -w)
-f, --perfparse
   perfparse output (only works with -c)
-l, --login=LOGIN
   Login for snmpv3 authentication (implies v3 protocol with MD5)
-x, --passwd=PASSWD
   Password for snmpv3 authentication
-P, --port=PORT
   SNMP port (Default 161)
-t, --timeout=INTEGER
   timeout for SNMP (Default: 5s)
-V, --version
   prints version number
-g (--rrdgraph)   Create a rrd base if necessary and add datas into this one
-S (--ServiceId)  centreon Service Id

EOT
}

# For verbose output
sub verb { my $t=shift; print $t,"\n" if defined($o_verb) ; }

sub check_options {
    Getopt::Long::Configure ("bundling");
    GetOptions(
        "H|hostname|host=s"         => \$OPTION{'host'},
        "C|community=s"             => \$OPTION{'snmp-community'},
        "snmp|snmp-version=s"       => \$OPTION{'snmp-version'},
        "port|P|snmpport|snmp-port=i"    => \$OPTION{'snmp-port'},
        "l|login|username=s"        => \$OPTION{'snmp-auth-user'},
        "x|passwd|authpassword|password=s" => \$OPTION{'snmp-auth-password'},
        "k|authkey=s"               => \$OPTION{'snmp-auth-key'},
        "authprotocol=s"            => \$OPTION{'snmp-auth-protocol'},
        "privpassword=s"            => \$OPTION{'snmp-priv-password'},
        "privkey=s"                 => \$OPTION{'snmp-priv-key'},
        "privprotocol=s"            => \$OPTION{'snmp-priv-protocol'},
        "maxrepetitions=s"          => \$OPTION{'maxrepetitions'},
        "t|timeout|snmp-timeout=i"  => \$OPTION{'snmptimeout'},
        "64-bits"                   => \$OPTION{'64-bits'},
        'v'     => \$o_verb,    'verbose'       => \$o_verb,
        'h'     => \$o_help,    'help'          => \$o_help,
        'V'     => \$o_version, 'version'       => \$o_version,
        's'     => \$o_svn,     'svn'           => \$o_svn,
        'w'     => \$o_fw,      'fw'            => \$o_fw,
        'a'     => \$o_ha,      'ha'            => \$o_ha,
        'm'     => \$o_mgmt,    'mgmt'          => \$o_mgmt,
        'p:s'   => \$o_policy,  'policy:s'      => \$o_policy,
        'c:s'   => \$o_conn,    'connexions:s'  => \$o_conn,
        'f'     => \$o_perf,    'perfparse'     => \$o_perf,
    );
    if (defined ($o_help) ) { help(); exit $ERRORS{"UNKNOWN"}};
    if (defined($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"}};
    # Check firewall options
    ($session_params) = Centreon::SNMP::Utils::check_snmp_options($ERRORS{'UNKNOWN'}, \%OPTION);
    if ( defined($o_conn)) {
      if ( ! defined($o_fw))
 	{ print "Cannot check connexions without checking fw\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
      my @warncrit=split(/,/ , $o_conn);
      if ( $#warncrit != 1 )
        { print "Put warn,crit levels with -c option\n";print_usage(); exit $ERRORS{"UNKNOWN"}}
      ($o_warn,$o_crit)=@warncrit;
      if ( isnnum($o_warn) || isnnum($o_crit) )
	{ print "Numeric values for warning and critical in -c options\n";print_usage(); exit $ERRORS{"UNKNOWN"}}
      if ($o_warn >= $o_crit)
	{ print "warning <= critical ! \n";print_usage(); exit $ERRORS{"UNKNOWN"}}
    }
    if ( defined($o_policy)) {
      if (! defined($o_fw))
	{ print "Cannot check policy name without checking fw\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
      if ($o_policy eq "")
        { print "Put a policy name !\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
    }
    if (defined($o_perf) && ! defined ($o_conn))
	{ print "Nothing selected for perfparse !\n";print_usage(); exit $ERRORS{"UNKNOWN"}}
    if (!defined($o_fw) && !defined($o_ha) && !defined($o_mgmt) && !defined($o_svn))
	{ print "Must select a product to check !\n";print_usage(); exit $ERRORS{"UNKNOWN"}}


}

########## MAIN #######

check_options();

my $session = Centreon::SNMP::Utils::connection($ERRORS{'UNKNOWN'}, $session_params);

########### Global checks #################

my $global_status=0; # global status : 0=OK, 1=Warn, 2=Crit
my ($resultat,$key)=(undef,undef);

##########  Check SVN status #############
my $svn_print="";
my $svn_state=0;

if (defined ($o_svn)) {
    $resultat = Centreon::SNMP::Utils::get_snmp_leef(\@svn_checks_oid, $session, $ERRORS{'UNKNOWN'});

    foreach $key ( keys %svn_checks) {
        verb("$svn_checks_n{$key} : $svn_checks{$key} / $$resultat{$key}");
        if ( $$resultat{$key} ne $svn_checks{$key} ) {
            $svn_print .= $svn_checks_n{$key} . ":" . $$resultat{$key} . " ";
            $svn_state=2;
        }
    }

    if ($svn_state == 0) {
        $svn_print="SVN : OK";
    } else {
        $svn_print="SVN : " . $svn_print;
    }
    verb("$svn_print");
}
##########  Check mgmt status #############
my $mgmt_state=0;
my $mgmt_print="";

if (defined ($o_mgmt)) {
    # Check all states
    $resultat=undef;
    $resultat = Centreon::SNMP::Utils::get_snmp_leef(\@mgmt_checks_oid, $session, $ERRORS{'UNKNOWN'});
    foreach $key ( keys %mgmt_checks) {
        verb("$mgmt_checks_n{$key} : $mgmt_checks{$key} / $$resultat{$key}");
        if ( $$resultat{$key} ne $mgmt_checks{$key} ) {
            $mgmt_print .= $mgmt_checks_n{$key} . ":" . $$resultat{$key} . " ";
            $mgmt_state=2;
        }
    }
    if ($mgmt_state == 0) {
        $mgmt_print="MGMT : OK";
    } else {
        $mgmt_print="MGMT : " . $mgmt_print;
    }
    verb("$svn_print");
}

########### Check fw status  ##############

my $fw_state=0;
my $fw_print="";
my $perf_conn=undef;

if (defined ($o_fw)) {
    # Check all states
    $resultat = Centreon::SNMP::Utils::get_snmp_leef(\@fw_checks, $session, $ERRORS{'UNKNOWN'});
    verb("State : $$resultat{$policy_state}");
    verb("Name : $$resultat{$policy_name}");
    verb("connections : $$resultat{$connections}");

    if ($$resultat{$policy_state} ne "Installed") {
        $fw_state=2;
        $fw_print .= "Policy:". $$resultat{$policy_state}." ";
        verb("Policy state not installed");
    }

    if (defined($o_policy)) {
        if ($$resultat{$policy_name} ne $o_policy) {
            $fw_state=2;
            $fw_print .= "Policy installed : $$resultat{$policy_name}";
        }
    }

    if (defined($o_conn)) {
        if ($$resultat{$connections} > $o_crit) {
            $fw_state=2;
            $fw_print .= "Connexions : ".$$resultat{$connections}." > ".$o_crit." ";
        } else {
            if ($$resultat{$connections} > $o_warn) {
                $fw_state=1;
                $fw_print .= "Connexions : ".$$resultat{$connections}." > ".$o_warn." ";
            }
        }
        $perf_conn=$$resultat{$connections};
    }

    if ($fw_state==0) {
        $fw_print="FW : OK";
    } else {
        $fw_print="FW : " . $fw_print;
    }
}
########### Check ha status  ##############

my $ha_state_n=0;
my $ha_print="";

if (defined ($o_ha)) {
    # Check all states
    $resultat =  Centreon::SNMP::Utils::get_snmp_leef(\@ha_checks_oid, $session, $ERRORS{'UNKNOWN'});
    foreach $key ( keys %ha_checks) {
        verb("$ha_checks_n{$key} : $ha_checks{$key} / $$resultat{$key}");
        if ( $$resultat{$key} ne $ha_checks{$key} ) {
            $ha_print .= $ha_checks_n{$key} . ":" . $$resultat{$key} . " ";
            $ha_state_n=2;
        }
    }
    #my $ha_mode		= "1.3.6.1.4.1.2620.1.5.11.0";  # "Sync only" : ha Working mode

    # get ha status table
    $resultat = Centreon::SNMP::Utils::get_snmp_table($ha_tables, $session, $ERRORS{'UNKNOWN'}, \%OPTION);
    my %status;
    my (@index,@oid) = (undef,undef);
    my $nindex=0;
    my $index_search= $ha_tables . $ha_tables_index;

    foreach $key ( keys %$resultat) {
        if ( $key =~ /$index_search/) {
            @oid=split (/\./,$key);
            pop(@oid);
            $index[$nindex]=pop(@oid);
            $nindex++;
        }
    }
    verb ("found $nindex ha softs");
    if ( $nindex == 0 ) {
        $ha_print .= " no ha soft found" if ($ha_state_n ==0);
        $ha_state_n=2;
    } else {
        my $ha_soft_name=undef;

    for (my $i=0;$i<$nindex;$i++) {
        $key=$ha_tables . $ha_tables_name . "." . $index[$i] . ".0";
        $ha_soft_name= $$resultat{$key};
        $key=$ha_tables . $ha_tables_state . "." . $index[$i] . ".0";
        if (($status{$ha_soft_name} = $$resultat{$key}) ne "OK") {
            $key=$ha_tables . $ha_tables_prbdesc . "." . $index[$i] . ".0";
            $status{$ha_soft_name} = $$resultat{$key};
            $ha_print .= $ha_soft_name . ":" . $status{$ha_soft_name} . " ";
            $ha_state_n=2
        }
        verb ("$ha_soft_name : $status{$ha_soft_name}");
    }
    }

    if ($ha_state_n == 0) {
        $ha_print = "HA : OK";
    } else {
        $ha_print = "HA : " . $ha_print;
    }
}

########## print results and exit

my $f_print=undef;

if (defined ($o_fw)) { $f_print = $fw_print }
if (defined ($o_svn)) { $f_print = (defined ($f_print)) ? $f_print . " / ". $svn_print : $svn_print }
if (defined ($o_ha)) { $f_print = (defined ($f_print)) ? $f_print . " / ". $ha_print : $ha_print }
if (defined ($o_mgmt)) { $f_print = (defined ($f_print)) ? $f_print . " / ". $mgmt_print : $mgmt_print }

my $exit_status=undef;
$f_print .= " / CPFW Status : ";
if (($ha_state_n+$svn_state+$fw_state+$mgmt_state) == 0 ) {
    $f_print .= "OK";
    $exit_status= $ERRORS{"OK"};
} else {
    if (($fw_state==1) || ($ha_state_n==1) || ($svn_state==1) || ($mgmt_state==1)) {
        $f_print .= "WARNING";
        $exit_status= $ERRORS{"WARNING"};
    } else {
        $f_print .= "CRITICAL";
        $exit_status=$ERRORS{"CRITICAL"};
    }
}

if (defined($o_perf) && defined ($perf_conn)) {
    $f_print .= " | fw_connexions=" . $perf_conn;
}

print "$f_print\n";
exit $exit_status;