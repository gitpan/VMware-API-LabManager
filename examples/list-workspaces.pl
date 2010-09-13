#!/usr/bin/perl

use Data::Dumper;
use Getopt::Long;
use VMware::API::LabManager;
use strict;

my $version = ( split ' ', '$Revision: 1.2 $' )[1];

### Configuration

my $username  = 'ppollard';
my $password  = 'z2A3p464';
my $orgname   = 'Global';
my $workspace = 'Main';
my $server    = '10.198.138.73'; # Source

my $labman = new VMware::API::LabManager (
  $username,        # Username
  $password,        # Password
  $server,          # Server
  $orgname,         # Org Name
  $workspace        # Workspace Name
);

my $wss = $labman->priv_GetAllWorkspaces();

print Dumper($wss);
