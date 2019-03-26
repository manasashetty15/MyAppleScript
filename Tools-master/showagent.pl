#!/opt/proofpoint/pps-8.0.1.1446/opt/perl/bin/perl

# MODIFIED TO PRINT FQDN NAMES, BUT NOT TAKING ACTION HERE

BEGIN {
    if ( ! $ENV{'PROOFPOINT_ROOT'} ) {
        print "The PROOFPOINT_ROOT environment variable isn't set.  Can't run\n";
        exit 1;
    }
}
use strict;
use warnings;

use Proofpoint::Log4perl qw( get_logger :levels :easy );
## use AppConfig qw ( :expand :argcount );
use Proofpoint::ServObject;
use Proofpoint::PPSControl;
use Proofpoint::Config;
use AppConfig qw( :expand :argcount );

my $_gridAgentManager;
sub gridAgentManager{
       require Proofpoint::Grid::AgentManager;
       $_gridAgentManager ||=Proofpoint::Grid::AgentManager->new();
       return $_gridAgentManager;
}


Log::Log4perl->easy_init ( {
        level => $DEBUG,
        file => '>>' . $ENV{'PROOFPOINT_ROOT'} . '/var/log/admind/deleteagent.log',
        layout => "%d{ISO8601} %p> %F{1}:%L %M - %m%n",
} );

my $config = AppConfig->new ( {
    CASE => 1,
} );


$config->define ( 'fqin=s' );
$config->define ( 'interactive',        { DEFAULT => 1, ARGCOUNT => ARGCOUNT_NONE } );
$config->define ( 'force',              { DEFAULT => 1, ARGCOUNT => ARGCOUNT_NONE } );
$config->define ( 'notify-agent',       { DEFAULT => 0, ARGCOUNT => ARGCOUNT_NONE } );
$config->getopt();


my $selfServ = Proofpoint::ServObject::getServer ( 'self' );
if ( $selfServ->{'service.assigned.configmaster'} == 1 ) {

    my $fqin;
    if ( $config->interactive() ) {
        $fqin = getAgentFQIN();
	exit 1;
    } 
    if ( ! $fqin ) {
        print "  An error occurred.  No FQIN was provided.  Use the interactive mode or the '--fqin' command line option'\n";
        exit 1;
    }
}

sub getAgentFQIN {
    my $servers = Proofpoint::ServObject::listServers();
    if ( scalar ( @{$servers} ) == 1 ) {
        fail ( 'This server has no agents to delete.' );
    }
    my $response = 'yes';

    my $agentServ;
    my $agentID = 0;
    if ( $response =~ /^\s*y/i ) {
	
	print "\n";
        my $agents = [];
        foreach my $server ( sort ( @{$servers} ) ) {
            next if ( $server->{'self'} == 1 );
            push ( @{$agents}, $server );
        }

            my $count = 1;
            foreach my $server ( @{$agents} ) {
                printf ( "  %2d: %s\n", $count, $server->{'id'} );
                $count++;
            }
   } 

}

