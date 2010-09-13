#!/usr/bin/perl

use Data::Dumper;
use Getopt::Long;
use VMware::API::LabManager;
use strict;

my $version = ( split ' ', '$Revision: 1.2 $' )[1];

my ( $username, $password, $server);
my $orgname   = 'Global';
my $workspace = 'Main';

my $ret = GetOptions ( 'username=s' => \$username, 'password=s' => \$password,
                       'orgname=s' => \$orgname, 'workspace=s' => \$workspace   
                       'server=s' => \$server );

my $labman = new VMware::API::LabManager (
  $username, $password, $server, $orgname, $workspace                        
);

my $org_id = 3; # SSL
my $start_workspace  = 9;  # Main
my $finish_workspace = 14; # Archive

my $configs = $labman->GetConfigurationByName('aaa test');
my $config = $configs->[0];

my $id     = $config->{id};
my $name   = $config->{name};

my $machines = $labman->ListMachines($id);
my @machineids;

for my $machine (@$machines) {
  push @machineids, $machine->{id};
}

print "Working with '$name' ($id)\n";

my $ret = $labman->priv_ConfigurationMove(
  $id,
  $finish_workspace,
  'true',
  $name,  
  $config->{description},
  $config->{autoDeleteInMilliSeconds},
  undef, #$id,
  \@machineids,
  'true'
);

if ( $ret =~ /^\d+$/ ) {
  print "Worked: $ret\n";
} else {
  print $labman->{ConfigurationMove}->{_context}->{_transport}->{_proxy}->{_http_response}->{_request}->{_content};
  print Dumper($ret);
}