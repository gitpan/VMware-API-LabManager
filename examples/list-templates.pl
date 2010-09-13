#!/usr/bin/perl

use Data::Dumper;
use Getopt::Long;
use VMware::API::LabManager;
use strict;

my $version = ( split ' ', '$Revision: 1.1 $' )[1];

my ( $username, $password, $server);
my $orgname   = 'Global';
my $workspace = 'Main';

my $ret = GetOptions ( 'username=s' => \$username, 'password=s' => \$password,
                       'orgname=s' => \$orgname, 'workspace=s' => \$workspace   
                       'server=s' => \$server );

my $labman = new VMware::API::LabManager (
  $username, $password, $server, $orgname, $workspace                        
);

my $orgs = $labman->priv_GetOrganizations();


for my $org (@$orgs) {
  my $this_orgname = $org->{Name};
  print "\nORG: $this_orgname\n";

  $labman->config( orgname => $this_orgname );

  my $templates = $labman->priv_ListTemplates();

  print Dumper($templates);
}
