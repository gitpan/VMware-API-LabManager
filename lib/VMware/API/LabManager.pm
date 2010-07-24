package VMware::API::LabManager;

use SOAP::Lite; # +trace => 'debug';
use Data::Dumper;

use strict;

=head1 NAME

VMware::API::LabManager - The VMware LabManager API

=head1 VERSION

$Revision: 1.1.1.1 $

=cut

our $VERSION =  ( split ' ', '$Revision: 1.1.1.1 $' )[1];

=head1 SYNOPSIS

This module has been tested using Labmanger 4.0 (4.0.1.1233). 

Code to checkout, deploy, undeploy and delete a configuration:

 	use VMware::API::LabManager;
 
	my $labman = VMware::API::LabManager->new('LM_Username','LM_Password','LM_Hostname','Organization_Name','WorkSpace_Name');

 	#Get the id of the config you are going to check out 
 	@lib_config_id = $labman->GetSingleConfigurationByName($libraryConfigName,"id");

 	#Checkout the config
 	$checked_out_config_id  = $labman->ConfigurationCheckout($lib_config_id[0],"NEW_WORKSPACE_NAME");

 	#Deploy the config
 	$labman->ConfigurationDeploy($checked_out_config_id,4); # The 4 is for the fencemode

	#Deploy the config to DVS
	$labman->priv_ConfigurationDeployEx2($checked_out_config_id,2); # 2 is the id of the network

 	#Undeploy the config
 	$labman->ConfigurationUndeploy($chkd_out_id);

 	#Delete the config
 	$labman->ConfigurationDelete($chkd_out_id);

	#Check for last SOAP error
    print $labman->getLastSOAPError();

=head1 DESCRIPTION

This module provides a Perl interface to VMWare's Labmanager SOAP interface. It 
has a one-to-one mapping for most of the commands exposed in the external API as 
well as a few commands exposed in the internal API. The most useful Internal API 
command is ConfigurationDeployEx2 which allows you to deploy to distributed 
virtual switches.  

Using this module you can checkout, deploy, undeploy and delete configurations. 
You can also get lists of configurations and guest information as well.

Lab Manager is a product created by VMWare that provides development and test 
teams with a virtual environment to deploy systems and networks of systems in a 
short period of a time. 

=head1 PERL MODULE METHODS

These methods are not direct API calls. They represent the methods that create
or  module as a "wrapper" for the Labmanager API.

=head2 new

This method creates the Labmanager object.

=head3 Arguments

=over 4

=item * username

=item * password

=item * hostname

=item * organization

=item * workspace

=back

=cut

sub new {
  my $class = shift @_;
  my $self  = {};
  
  my $username  = shift @_;
  my $password  = shift @_;
  my $hostname  = shift @_;
  my $orgname   = shift @_;
  my $workspace = shift @_;
  
  $self->{debug} = shift @_;
  $self->{debug} = 0 unless defined $self->{debug};

  our $die_on_fault = shift @_;
  $die_on_fault = 1 unless defined $die_on_fault;
  
	$self->{soap} = SOAP::Lite
		-> on_action(sub { return "http://vmware.com/labmanager/" . $_[1]; } )
		-> default_ns('http://vmware.com/labmanager')
		-> proxy('https://' . $hostname . '/LabManager/SOAP/LabManager.asmx');

	$self->{soap_priv} = SOAP::Lite
		-> on_action(sub { return "http://vmware.com/labmanager/" . $_[1]; } )
		-> default_ns('http://vmware.com/labmanager')
		-> proxy('https://' . $hostname . '/LabManager/SOAP/LabManagerInternal.asmx');

	$self->{soap}->readable(1);
	$self->{soap_priv}->readable(1);

	$self->{auth_header} = SOAP::Header->new(
		name => 'AuthenticationHeader',
		attr => { xmlns => "http://vmware.com/labmanager" },
		value => { username => $username, password => $password, organizationname => $orgname, workspacename => $workspace  },
		);

  if ( $self->{soap}->fault ){ $self->{LASTERROR} = $self->{soap}->fault }

  bless($self, $class);
  $self->_debug("Loaded VMware::API::LabManager v" . our $VERSION . "\n") if $self->{debug};
  return $self;
}

=head3 getLastSOAPError

Returns last error reported by SOAP service.

=cut

sub getLastSOAPError {
  my $self = shift @_;
  if ( $self->{LASTERROR} and $self->{LASTERROR}->{data} ) {
		return join(': ', 'LabManager SOAP error', 
			$self->{LASTERROR}->{data}->faultcode, 
			$self->{LASTERROR}->{data}->faultstring, 
			$self->{LASTERROR}->{data}->faultdetail
		) . "\n";
  }
}

### Internal methods

sub _debug {
  my $self = shift @_;
  while ( my $debug = shift @_ ) {
    chomp $debug;
    print STDERR "DEBUG: $debug\n";
  }
}

sub _fault {
  my $self = shift @_;
  my $data = shift @_;
  my $text;
  
  if ( ref $data and defined $data->{faultstring} ) {
    $text = $data->{faultstring};
  } elsif ( ref $data and ref $data->{detail} and defined $data->{detail}->{message}->{format} ) {
    $text = $data->{detail}->{message}->{format};
  } else {
    $text = $data;
    $data = '';
  }

  if ( our $die_on_fault ) {
    warn "ERROR DETAILS:\n" . Dumper($data) if $self->{debug};
    die "\n\nERROR: $text\n";
  } else {
    $self->{LASTERROR}->{data} = $data;
    $self->{LASTERROR}->{text} = $text;
  }
}

=head1 PUBLIC API METHODS

This methods provide a direct mapping to the public API calls for Labmanager.

=head2 ConfigurationCapture

This method captures a Workspace configuration and saves into the library.  

=head3 Arguments

=over 4

=item * Configuration ID - Use the GetConfigurationByName method to retrieve this if you do not know it.

=item * New library name - The name that you want the captured config to be.

=back

=head3 Returns

ID on success. Fault object on fault.

=cut

sub ConfigurationCapture {
  my $self       = shift @_;
  my $configID   = shift @_;
  my $newLibName = shift @_;

  $self->{ConfigurationCapture} = 
    $self->{soap}->ConfigurationCapture( 
      $self->{auth_header}, 
      SOAP::Data->name('configurationId' => $configID   )->type('s:int'),
      SOAP::Data->name('newLibraryName'  => $newLibName )->type('s:string')
    );

  if ( $self->{ConfigurationCapture}->fault ) {
    $self->_fault( $self->{ConfigurationCapture}->fault );
    return $self->{ConfigurationCapture}->fault;
  } else {
    return $self->{ConfigurationCapture}->result;
  }
}

=head2 ConfigurationCheckout

This method checks out a configuration from the configuration library and moves it to the Workspace under a different name. It returns the ID of the checked out configuration in the WorkSpace.

WARNING: If you get the following SOAP Error: 
=over 8
Expecting single row, got multiple rows for: SELECT * FROM BucketWithParent WHERE name = N'Main' ---> Expecting single row, got multiple rows for: SELECT * FROM BucketWithParent WHERE name = N'Main'
=back
This is because there are multiple workspaces named "Main", in different organizations. Apparently this API call doesn't limit the check for workspace name against the organization you authenticated with.

A workaround is to make sure you use this call on a uniquely name workspace or to use a private call (such as priv_LibraryCloneToWorkspace) instead.

=head3 Arguments

=over 4

=item * Configuration ID - Use the GetConfigurationByName method to retrieve this if you do not know it.

=item * New workspace name - The name you want the new config in the workspace to be.

=back

=cut

sub ConfigurationCheckout {
  my $self       = shift @_;
  my $configID   = shift @_;
  my $configName = shift @_; 

  $self->{ConfigurationCheckout} = 
    $self->{soap}->ConfigurationCheckout( 
		$self->{auth_header}, 
		SOAP::Data->name('configurationId' => $configID   )->type('s:int'),   # Config to check out
        SOAP::Data->name('workspaceName'   => $configName )->type('s:string') # New name it shall be
	);

  if ( $self->{ConfigurationCheckout}->fault ) {
    $self->_fault( $self->{ConfigurationCheckout}->fault );
    return $self->{ConfigurationCheckout}->fault;
  } else {
    return $self->{ConfigurationCheckout}->result;
  }
}

=head2 ConfigurationClone

This method clones a Workspace configuration, saves it in a storage server, and makes it visible in the Workspace under the new name. Arguements:

=head3 Arguments

=over 4

=item * Configuration ID - Use the GetConfigurationByName method to retrieve this if you do not know it.

=item * New workspace name - The name of the clone that is being created.

=back

=cut

sub ConfigurationClone {
  my $self = shift @_;
  my $configID = shift @_;
  my $newWSName = shift @_;

	$self->{ConfigurationClone} =
		$self->{soap}->ConfigurationClone($self->{auth_header}, 
		SOAP::Data->name('configurationId' => $configID )->type('s:int'),
        SOAP::Data->name('newWorkspaceName' => $newWSName )->type('s:string') );

  if ( $self->{ConfigurationClone}->fault ) {
    $self->_fault( $self->{ConfigurationClone}->fault );
    return $self->{ConfigurationClone}->fault;
  } else {
    return $self->{ConfigurationClone}->result;
  }
}

=head2 ConfigurationDelete

This method deletes a configuration from the Workspace. You cannot delete a deployed configuration. Doesn't return anything. Arguments:

=head3 Arguments

=over 4

=item * Configuration ID - Use the GetConfigurationByName method to retrieve this if you do not know it.

=back

=cut


sub ConfigurationDelete {
  my $self = shift @_;
  my $configID = shift @_;

  $self->{ConfigurationDelete} = 
    $self->{soap}->ConfigurationDelete( $self->{auth_header}, 
    SOAP::Data->name('configurationId' => $configID)->type('s:int')
  );

  if ( $self->{ConfigurationDelete}->fault ) {
    $self->_fault( $self->{ConfigurationDelete}->fault );
    return $self->{ConfigurationDelete}->fault;
  } else {
    return $self->{ConfigurationDelete}->result;
  }
}


=head2 ConfigurationDeploy

This method allows you to deploy an undeployed configuration which resides in the Workspace.

=head3 Arguments

=over 4

=item * Configuration ID - Use the GetConfigurationByName method to retrieve this if you do not know it.

=item * Fencemode - 1 = not fenced; 2 = block traffic in and out; 3 = allow out ; 4 allow in and out

=back

=cut

sub ConfigurationDeploy {
  my $self      = shift @_;
  my $configID  = shift @_;
  my $fencemode = shift @_; # 1 = not fenced; 2 = block traffic in and out; 3 = allow out ; 4 allow in and out

	$self->{ConfigurationDeploy} = 
		$self->{soap}->ConfigurationDeploy( $self->{auth_header}, 
		SOAP::Data->name('configurationId' => $configID )->type('s:int'),
		SOAP::Data->name('isCached' => "false")->type('s:boolean'), 
		SOAP::Data->name('fenceMode' => $fencemode)->type('s:int') );
		
  if ( $self->{ConfigurationDeploy}->fault ) {
    $self->_fault( $self->{ConfigurationDeploy}->fault );
    return $self->{ConfigurationDeploy}->fault;
  } else {
    return $self->{ConfigurationDeploy}->result;
  }
}

=head2 ConfigurationPerformAction

This method performs one of the following configuration actions as indicated by the action identifier:

=over 4

=item	1 Power On. Turns on a configuration.

=item	2 Power Off. Turns off a configuration. Nothing is saved.

=item	3 Suspend. Freezes the CPU and state of a configuration.

=item	4 Resume. Resumes a suspended configuration.

=item	5 Reset. Reboots a configuration.

=item	6 Snapshot. Saves a configuration state at a specific point in time.

=back

=head3 Arguments

=over 4

=item * Configuration ID - Use the GetConfigurationByName method to retrieve this if you do not know it.

=item * Action - use a numerical value from the list above.

=back

=cut

sub ConfigurationPerformAction {
  my $self     = shift @_;
  my $configID = shift @_;
  my $action   = shift @_; # 1-Pwr On, 2-Pwr off, 3-Suspend, 4-Resume, 5-Reset, 6-Snapshot
  
  $self->{ConfigurationPerformAction} = 
    $self->{soap}->ConfigurationPerformAction( $self->{auth_header}, 
	SOAP::Data->name('configurationId' => $configID )->type('s:int'),
	SOAP::Data->name('action' => $action )->type('s:int') );

  if ( $self->{ConfigurationPerformAction}->fault ) {
    $self->_fault( $self->{ConfigurationPerformAction}->fault );
    return $self->{ConfigurationPerformAction}->fault;
  } else {
    return $self->{ConfigurationPerformAction}->result;
  }
}

=head2 ConfigurationSetPublicPrivate

Use this call to set the state of a configuration to public” or private.” If the configuration state is public, others are able to access this configuration. If the configuration is private, only its owner can view it.

=head3 Arguments

=over 4

=item * Configuration ID - Use the GetConfigurationByName method to retrieve this if you do not know it.

=item * True or False (boolean) - Accepts true | false | 1 | 0

=back

=cut

sub ConfigurationSetPublicPrivate {
  my $self = shift @_;
  my $conf = shift @_;
  my $bool = shift @_;

  $self->{ConfigurationSetPublicPrivate} = 
    $self->{soap}->ConfigurationSetPublicPrivate( $self->{auth_header}, 
    SOAP::Data->name('configurationId' => $conf )->type('s:int'),
    SOAP::Data->name('isPublic'        => $bool )->type('s:boolean')
  );

  if ( $self->{ConfigurationSetPublicPrivate}->fault ) {
    $self->_fault( $self->{ConfigurationSetPublicPrivate}->fault );
    return $self->{ConfigurationSetPublicPrivate}->fault;
  } else {
    return $self->{ConfigurationSetPublicPrivate}->result;
  }
}

=head2 ConfigurationUndeploy

Undeploys a configuration in the Workspace. Nothing is returned.

=head3 Arguments

=over 4

=item * Configuration ID - Use the GetConfigurationByName method to retrieve this if you do not know it.

=back

=cut

sub ConfigurationUndeploy {
  my $self = shift @_;
  my $configID = shift @_;

	$self->{ConfigurationUndeploy} = 
		$self->{soap}->ConfigurationUndeploy( $self->{auth_header}, 
		SOAP::Data->name('configurationId' => $configID )->type('s:int'));

  if ( $self->{ConfigurationUndeploy}->fault ) {
    $self->_fault( $self->{ConfigurationUndeploy}->fault );
    return $self->{ConfigurationUndeploy}->fault;
  } else {
    return $self->{ConfigurationUndeploy}->result;
  }
}

=head2 GetConfiguration

This method prints a list of attributes of a Configuration matching the configuration ID passed. It will return an array if you specify which attributes you would like to access

=head3 Arguments

=over 4

=item * Config ID

=back

=head3 Attributes

=over 4

=item * 	mustBeFenced

=item *	autoDeleteDateTime

=item * 	bucketName

=item * 	name

=item *	autoDeleteInMilliSeconds

=item * 	description

=item * 	isDeployed

=item * 	fenceMode

=item * 	id

=item * 	type

=item * 	isPublic

=item * 	dateCreated

=back

=cut

sub GetConfiguration {
  my $self = shift @_;
  my $conf = shift @_;
		
  $self->{GetConfiguration} = 
    $self->{soap}->GetConfiguration(
      $self->{auth_header}, 
      SOAP::Data->name('id' => $conf )->type('s:int')
    );

  if ( $self->{GetConfiguration}->fault ) {
    $self->_fault( $self->{GetConfiguration}->fault );
    return $self->{GetConfiguration}->fault;
  } else {
    return $self->{GetConfiguration}->result;
  }
}

=head2 GetMachine

This call takes the numeric identifier of a machine and returns its corresponding Machine object.

=head3 Arguments

=over 4

=item * Machine ID - Use GetMachineByName to retrieve this

=back

=head3 Attributes

=over 4

=item * configID

=item * macAddress

=item * status

=item * OwnerFullName

=item * name

=item * description

=item * isDeployed

=item * internalIP

=item * memory

=item * DatastoreNameResidesOn

=item * id

=back

=cut

sub GetMachine {
  my $self = shift @_;
  my $id   = shift @_;

  $self->{GetMachine} = 
    $self->{soap}->GetMachine(
      $self->{auth_header}, 
	  SOAP::Data->name('machineId' => $id)->type('s:int') # mislabeled "machineID" by PUB API docs
	);

  if ( $self->{GetMachine}->fault ) {
    $self->_fault( $self->{GetMachine}->fault );
    return $self->{GetMachine}->fault;
  } else {
    return $self->{GetMachine}->result;
  }
}


=head2 GetMachineByName

This call takes a configuration identifier and a machine name and returns the matching Machine object.

=head3 Arguments

=over 4 

=item * Configuration ID - Config where Guest VM lives

=item * Name of guest

=item * Attribute(s) (optional) - if left blank, prints out and returns an array of all attributes.

=back

=head3 Attributes

=over 4

=item * configID

=item * macAddress

=item * status

=item * OwnerFullName

=item * name

=item * description

=item * isDeployed

=item * internalIP

=item * memory

=item * DatastoreNameResidesOn

=item * id

=back

=cut

sub GetMachineByName
{
	my($self) = shift @_;
	my($config) = shift @_;
	my($name) = shift @_;
	push(my(@attribs), @_);
	my @myattribs;
		
	$self->{GetMachineByName} = 
		$self->{soap}->GetMachineByName( $self->{auth_header}, 
		SOAP::Data->name('configurationId' => $config)->type('s:int'),
		SOAP::Data->name('name' => $name)->type('s:string'));

  if ( $self->{GetMachineByName}->fault ) {
    $self->_fault( $self->{GetMachineByName}->fault );
    return $self->{GetMachineByName}->fault;
  } else {
    return $self->{GetMachineByName}->result;
  }
}

=head2 GetSingleConfigurationByName

This call takes a configuration name, searches for it in both the configuration library and workspace and returns its corresponding Configuration object. Returns an array of attributes or one or more specified attributes.

=head3 Arguments

=over 4

=item * Configuration name 

=item * Attribute(s) (optional) - if left blank, prints out and returns an array of all attributes.

=back

=head3 Attributes

=over 4

=item * mustBeFenced

=item * autoDeleteDateTime

=item * bucketName  (aka workspace)

=item * name

=item * autoDeleteInMilliSeconds

=item * description

=item * isDeployed

=item * fenceMode

=item * id

=item * type

=item * isPublic

=item * dateCreated

=back

=cut

sub GetSingleConfigurationByName {
  my $self    = shift @_;
  my $config  = shift @_;
  my @attribs = @_;
  my @myattribs;
		
	$self->{GetSingleConfigurationByName} = 
		$self->{soap}->GetSingleConfigurationByName( $self->{auth_header}, 
		SOAP::Data->name('name' => $config)->type('s:string'));

  if ( $self->{GetSingleConfigurationByName}->fault ) {
    $self->_fault( $self->{GetMachineByName}->fault );
    return $self->{GetSingleConfigurationByName}->fault;
  } else {
    return $self->{GetSingleConfigurationByName}->result;
  }
}

=head2 listconfigurations($type)

This method returns an array or arrayref of configuration objects for the current
workspace or library.

It depends on configuration type requested.

=head3 Arguments

=over 4

=item * configurationType (Configuration Type must be either 1 for Workspace or 2 for Library) 

=back

=cut

sub ListConfigurations {
  my $self = shift @_;
  my $type = shift @_; #1 =WorkSpace, 2=Library 

  $self->_debug("LISTING CONFIGURATIONS") if $self->{debug};

  unless ($type == 1 || $type == 2 ) {
    $self->{LASTERROR} = "Configuration Type must be either 1 for Workspace or 2 for Library";
    $self->_fault( $self->{LASTERROR} );
  }

  $self->{ListConfigurations} = $self->{soap}->ListConfigurations( $self->{auth_header}, SOAP::Data->name('configurationType' => $type)->type('s:int'));

  if ( $self->{ListConfigurations}->fault ) {
    $self->_fault( $self->{ListConfigurations}->fault );
    return $self->{ListConfigurations}->fault;
  }

  my $ret = $self->{ListConfigurations}->result;

  my $array = [];
  $array = [ $ret->{Configuration} ] if ref $ret and ref $ret->{Configuration} eq 'HASH';
  $array =   $ret->{Configuration}   if ref $ret and ref $ret->{Configuration} eq 'ARRAY';
  
  return wantarray ? @$array : $array;
}

=head2 ListMachines

This method returns an array of type Machine. The method returns one Machine object for each virtual machine in a configuration.

=head3 Arguments

=over 4

=item * Configuration ID

=back

=cut


sub ListMachines {
  my $self   = shift @_;
  my $config = shift @_;
  
  $self->{ListMachines} = 
    $self->{soap}->ListMachines( $self->{auth_header}, 
    SOAP::Data->name('configurationId' => $config)->type('s:int'));
 
  if ( $self->{ListMachines}->fault ) {
    $self->_fault( $self->{ListMachines}->fault );
    return $self->{ListMachines}->fault;
  }
   
  my $ret = $self->{ListMachines}->result;

  my $array = [];
  $array = [ $ret->{Machine} ] if ref $ret and ref $ret->{Machine} eq 'HASH';
  $array =   $ret->{Machine}   if ref $ret and ref $ret->{Machine} eq 'ARRAY';

  return wantarray ? @$array : $array;
}



# Not Supported, but works (I believe)
sub GetConsoleAccessInfo
{
	# Attribs: ServerAddress, ServerPort,VmxLocation,Ticket
	my($self) = shift @_;
	my($machineId) = shift @_;
	push(my(@attribs), @_);
	my @myattribs;

	$self->{GetConsoleAccessInfo} = 
		$self->{soap}->GetConsoleAccessInfo( $self->{auth_header}, 
		SOAP::Data->name('machineId' => $machineId)->type('s:int'));

  if ( $self->{GetConsoleAccessInfo}->fault ) {
    $self->_fault( $self->{GetConsoleAccessInfo}->fault );
    return $self->{GetConsoleAccessInfo}->fault;
  } else {
    return $self->{GetConsoleAccessInfo}->result;
  }
}	


=head2 LiveLink

This method allows you to create a LiveLink URL to a library configuration. Responds with a livelink URL

=head3 Arguments

=over 4

=item * config Name

=back

=cut

sub LiveLink
{
	my($self) = shift @_;
	my($configName) = shift @_;
	$self->{LiveLink} = 
		$self->{soap}->LiveLink( $self->{auth_header}, 
		SOAP::Data->name('configName' => $configName)->type('s:string'));

  if ( $self->{LiveLink}->fault ) {
    $self->_fault( $self->{LiveLink}->fault );
    return $self->{LiveLink}->fault;
  } else {
    return $self->{LiveLink}->result;
  }
}

=head2 MachinePerformAction

This method performs one of the following machine actions as indicated by the action identifier:

=over 4

=item 1  Power on. Turns on a machine.

=item 2  Power off. Turns off a machine. Nothing is saved.

=item 3  Suspend. Freezes a machine CPU and state.

=item 4  Resume. Resumes a suspended machine.

=item 5  Reset. Reboots a machine.

=item 6  Snapshot. Save a machine state at a specific point in time.

=item 7  Revert. Returns a machine to a snapshot state.

=item 8  Shutdown. Shuts down a machine before turning off.

=back

=head3 Arguments

=over 4

=item * Machine ID

=item * Action (use numeral from list aboive)

=back

=cut

sub MachinePerformAction {
  my $self     = shift @_;
  my $configID = shift @_;
  my $action   = shift @_;  # Actions: 1-Pwr On, 2-Pwr off, 3-Suspend, 4-Resume, 5-Reset, 6-Snapshot , 7-Revert, 8-Shutdown

  $self->{MachinePerformAction} = 
    $self->{soap}->MachinePerformAction( $self->{auth_header}, 
	SOAP::Data->name('machineId' => $configID )->type('s:int'),
	SOAP::Data->name('action' => $action )->type('s:int') );

  if ( $self->{MachinePerformAction}->fault ) {
    $self->_fault( $self->{MachinePerformAction}->fault );
    return $self->{MachinePerformAction}->fault;
  } else {
    return $self->{MachinePerformAction}->result;
  }
}

=head1 INTERNAL API METHODS

This methods provide a direct mapping to internal API calls for Labmanager. 
These calls are not publically supported by VMware and may change between
releases of the Labmanager product.

=cut

=head2 priv_ConfigurationAddMachineEx

=head3 Arguments

=over 4

=item * id - ID of the configuration.

=item * template_id - ID of the template to be used.

=item * name - The name for the virtual machine.

=item * desc - Description for the virtual machine.

=item * boot_seq - Boot sequence order (0 by default).

=item * boot_delay - Boot delay (0 by default).

=item * netInfo - Array of network information for the virtual machine.

=back

=cut

sub priv_ConfigurationAddMachineEx {
  my $self = shift @_;
  
  my $ipaddress  = '10.10.220.10';
  my $macAddress = '00:50:DE:AD:BE:EF';
  
  $_[4] = 0 unless $_[4];
  $_[5] = 0 unless $_[5];

  my $eth0 = SOAP::Data->name('NetInfo'    => \SOAP::Data->value(
               SOAP::Data->name('networkId'   => 1           )->type('s:int'),
	           SOAP::Data->name('nicId'       => 0           )->type('s:int'),
	           #SOAP::Data->name('vmxSlot'     => 1           )->type('s:int'),
	           SOAP::Data->name('macAddress'  => $macAddress )->type('s:string'),
	           SOAP::Data->name('resetMac'    => 'true'      )->type('s:boolean'),
	           SOAP::Data->name('ipAddress'   => $ipaddress  )->type('s:string'),
	           SOAP::Data->name('ipAddressingMode' => 'STATIC_MANUAL')->type('s:string'),
	           SOAP::Data->name('netmask'     => '255.255.255.0')->type('s:string'),
	           SOAP::Data->name('gateway'     => '10.10.220.1')->type('s:string'),
	           SOAP::Data->name('dns1'        => '4.2.2.1')->type('s:string'),
	           SOAP::Data->name('dns2'        => '4.2.2.2')->type('s:string'),
	           SOAP::Data->name('isConnected' => 1           )->type('s:int'),
	         ));

  $self->{ConfigurationAddMachineEx} = 
    $self->{soap_priv}->ConfigurationAddMachineEx(
      $self->{auth_header}, 
	  SOAP::Data->name('id'         =>$_[0])->type('s:int'),
	  SOAP::Data->name('template_id'=>$_[1])->type('s:int'),
	  SOAP::Data->name('name'       =>$_[2])->type('s:string'),
	  SOAP::Data->name('desc'       =>$_[3])->type('s:string'),
	  SOAP::Data->name('boot_seq'   =>$_[4])->type('s:int'),
	  SOAP::Data->name('boot_delay' =>$_[5])->type('s:int'),
	  SOAP::Data->name('netInfo'    => \SOAP::Data->value(
          #$eth0,
	    )
	  )
	);

  if ( $self->{ConfigurationAddMachineEx}->fault ) {
    $self->_fault( $self->{ConfigurationAddMachineEx}->fault );
    return $self->{ConfigurationAddMachineEx}->fault;
  } else {
    return $self->{ConfigurationAddMachineEx}->result;
  }
}

=head2 priv_ConfigurationCaptureEx

This method captures a Workspace configuration and saves into the library.  

=head3 Arguments

=over 4

=item * Configuration ID - Use the GetConfigurationByName method to retrieve this if you do not know it.

=item * New library name - The name that you want the captured config to be.

=item * libraryDescription

=item * isGoldMaster

=item * storageName

=item * storageLeaseInMilliseconds

=back

=head3 Returns

ID on success. Fault object on fault.

=cut

sub priv_ConfigurationCaptureEx {
  my $self               = shift @_;
  my $configurationId    = shift @_;
  my $newLibraryName     = shift @_;
  my $libraryDescription = shift @_;
  my $isGoldMaster       = shift @_;
  my $storageName        = shift @_;
  my $storageLeaseInMilliseconds = shift @_ || 0;

  $isGoldMaster eq 'false' unless $isGoldMaster =~ /^true$/i;

  $self->{ConfigurationCaptureEx} = 
    $self->{soap_priv}->ConfigurationCaptureEx( 
      $self->{auth_header}, 
      SOAP::Data->name('configurationId'            => $configurationId            )->type('s:int'),
      SOAP::Data->name('newLibraryName'             => $newLibraryName             )->type('s:string'),
      SOAP::Data->name('libraryDescription'         => $libraryDescription         )->type('s:string'),
      SOAP::Data->name('isGoldMaster'               => $isGoldMaster               )->type('s:boolean'),
      SOAP::Data->name('storageName'                => $storageName                )->type('s:string'),
      SOAP::Data->name('storageLeaseInMilliseconds' => $storageLeaseInMilliseconds )->type('s:long')
    );

  if ( $self->{ConfigurationCaptureEx}->fault ) {
    $self->_fault( $self->{ConfigurationCaptureEx}->fault );
    return $self->{ConfigurationCaptureEx}->fault;
  } else {
    return $self->{ConfigurationCaptureEx}->result;
  }
}

=head2 priv_ConfigurationCopy

=cut

sub priv_ConfigurationCopy {
  my $self        = shift @_;
  my $sg_id       = shift @_;
  my $name        = shift @_;
  my $description = shift @_;
  
  my $machines = shift @_;
  my $storage = shift @_;
  
  my @machine_data;

  for my $machine (@$machines) {
    my @elements;
    for my $element ( keys %$machine ) {
      push @elements, SOAP::Data->name( $element, $machine->{$element} );
    }
    push @machine_data, SOAP::Data->name('machine' => \SOAP::Data->value(@elements));
  }
  
  $self->{ConfigurationCopy} = 
    $self->{soap_priv}->ConfigurationCopy( 
      $self->{auth_header}, 
      SOAP::Data->name('sg_id'       => $sg_id       )->type('s:int'),
      SOAP::Data->name('name'        => $name        )->type('s:string'),
      SOAP::Data->name('description' => $description )->type('s:string'),
	  SOAP::Data->name('configurationCopyData' => \SOAP::Data->value(
        SOAP::Data->name('VMCopyData' => \SOAP::Data->value(
          @machine_data,
          SOAP::Data->name('storageServerName' => $storage )->type('s:string')
        ))
	  ))
    );

  if ( $self->{ConfigurationCopy}->fault ) {
    $self->_fault( $self->{ConfigurationCopy}->fault );
    return $self->{ConfigurationCopy}->fault;
  } else {
    return $self->{ConfigurationCopy}->result;
  }
}

=head2 priv_ConfigurationCreateEx

Creates and empty configuration.

=head3 Arguments

=over 4

=item * Name - The name of the configuration 

=item * Description - The description of the configuration

=back

=head3 Returns

ID of the configuration on success.

A fault object on fault.

=cut

sub priv_ConfigurationCreateEx {
  my $self = shift @_;
  my $name = shift @_;
  my $desc = shift @_;
  
  $self->{ConfigurationCreateEx} = 
    $self->{soap_priv}->ConfigurationCreateEx(
      $self->{auth_header}, 
	  SOAP::Data->name('name'=>$name)->type('s:string'),
	  SOAP::Data->name('desc'=>$desc)->type('s:string')
	);

  if ( $self->{ConfigurationCreateEx}->fault ) {
    $self->_fault( $self->{ConfigurationCreateEx}->fault );
    return $self->{ConfigurationCreateEx}->fault;
  } else {
    return $self->{ConfigurationCreateEx}->result;
  }
}

=head2 priv_ConfigurationDeployEx2

This method allows you to deploy an undeployed configuration which resides in the Workspace to a Distributed Virtual Switch. Arguments:

=head3 Arguments

=over 4

=item * Configuration ID - Use the GetConfigurationByName method to retrieve this if you do not know it. 

=item * Network ID

=item * Fencemode(string) - Choices: Nonfenced or FenceBlockInAndOut or FenceAllowOutOnly or FenceAllowInAndOut

=back

=cut

sub priv_ConfigurationDeployEx2 {
   my $self = shift @_;
   my $configID = shift @_;
   my $networkId = shift @_;
   my $fenceMode = 'FenceAllowInAndOut';

   my $net_elem = SOAP::Data->name( 'FenceNetworkOption' => \SOAP::Data->value(
                        SOAP::Data->name('configuredNetID' => $networkId)->type('s:int'),
                        SOAP::Data->name('DeployFenceMode'=> $fenceMode)->type('tns:SOAPFenceMode')
                     )
                  );

   my $bridge_elem = SOAP::Data->name( 'BridgeNetworkOption' => \SOAP::Data->value(
                           SOAP::Data->name('externalNetId' => $networkId)->type('s:int')
                        )
                     );
  
   my @net_array;
   my @bridge_array;
   push(@net_array,$net_elem);
   push(@bridge_array,$bridge_elem);

   $self->{ConfigurationDeployEx2} =
      $self->{soap_priv}->ConfigurationDeployEx2( $self->{auth_header},
      SOAP::Data->name('configurationId' => $configID )->type('s:int'),
      SOAP::Data->name('honorBootOrders' => 1)->type('s:boolean'),
      SOAP::Data->name('startAfterDeploy' => 1)->type('s:boolean'),
      SOAP::Data->name('fenceNetworkOptions' => \SOAP::Data->value( @net_array )->type('tns:ArrayOfFenceNetworkOption')),
		#Do not uncomment unless you know how to make it work:
      #SOAP::Data->name('bridgeNetworkOptions' =>\SOAP::Data->value(  @bridge_array )->type('tns:ArrayOfBridgeNetworkOption')),
      SOAP::Data->name('isCrossHost' => 1)->type('s:boolean')
      );

  if ( $self->{ConfigurationDeployEx2}->fault ) {
    $self->_fault( $self->{ConfigurationDeployEx2}->fault );
    return $self->{ConfigurationDeployEx2}->fault;
  } else {
    return $self->{ConfigurationDeployEx2}->result;
  }
}

=head2 priv_ConfigurationExport

=cut

sub priv_ConfigurationExport {
  my $self = shift @_;
  my $conf = shift @_;
  my $unc  = shift @_;
  my $user = shift @_;
  my $pass = shift @_;
  
  $self->{ConfigurationExport} = 
    $self->{soap_priv}->ConfigurationExport(
      $self->{auth_header}, 
	  SOAP::Data->name('configId' =>$conf)->type('s:int'),
	  SOAP::Data->name('uncPath'  =>$unc )->type('s:string'),
	  SOAP::Data->name('username' =>$user)->type('s:string'),
	  SOAP::Data->name('password' =>$pass)->type('s:string'),
	);

  if ( $self->{ConfigurationExport}->fault ) {
    $self->_fault( $self->{ConfigurationExport}->fault );
    return $self->{ConfigurationExport}->fault;
  } else {
    return $self->{ConfigurationExport}->result;
  }
}


=head2 priv_ConfigurationImport

=cut

sub priv_ConfigurationImport {
  my $self = shift @_;
  my $unc  = shift @_;
  my $user = shift @_;
  my $pass = shift @_;
  my $name = shift @_;
  my $desc = shift @_;
  my $stor = shift @_;
  
  $self->{ConfigurationImport} = 
    $self->{soap_priv}->ConfigurationImport(
      $self->{auth_header},
	  SOAP::Data->name('UNCPath'     =>$unc )->type('s:string'),
	  SOAP::Data->name('dirUsername' =>$user)->type('s:string'),
	  SOAP::Data->name('dirPassword' =>$pass)->type('s:string'),
	  SOAP::Data->name('name'        =>$name)->type('s:string'),
	  SOAP::Data->name('description' =>$desc)->type('s:string'),
	  SOAP::Data->name('storageName' =>$stor)->type('s:string'),
	);

  if ( $self->{ConfigurationImport}->fault ) {
    $self->_fault( $self->{ConfigurationImport}->fault );
    return $self->{ConfigurationImport}->fault;
  } else {
    return $self->{ConfigurationImport}->result;
  }
}

=head2 priv_GetObjectConditions

=head3 Arguments

=over 4

=item * objectType - Integer representing the object type:

  VM = 1
  MANAGED_SERVER = 2
  RESOURCE_POOL = 3
  CONFIGURATION = 4

=item * objectID - Object id number

=back

=cut

sub priv_GetObjectConditions {
  my $self = shift @_;
  my $objectType = shift @_;
  my $objectID   = shift @_;
  
  $self->{GetObjectConditions} = 
    $self->{soap_priv}->GetObjectConditions(
      $self->{auth_header}, 
	  SOAP::Data->name('objectType'=>$objectType)->type('s:int'),
	  SOAP::Data->name('objectID'=>$objectID)->type('s:int'),
	);

  if ( $self->{GetObjectConditions}->fault ) {
    $self->_fault( $self->{GetObjectConditions}->fault );
    return $self->{GetObjectConditions}->fault;
  } else {
    return $self->{GetObjectConditions}->result;
  }
}

=head2 priv_GetNetworkInfo

=head3 Arguments

=over 4

=item * vmID - VM id number

=back

=cut

sub priv_GetNetworkInfo {
  my $self = shift @_;
  my $vmid = shift @_;
  
  $self->{GetNetworkInfo} = 
    $self->{soap_priv}->GetNetworkInfo(
      $self->{auth_header}, 
	  SOAP::Data->name('vmID'=>$vmid)->type('s:int')
	);

  if ( $self->{GetNetworkInfo}->fault ) {
    $self->_fault( $self->{GetNetworkInfo}->fault );
    return $self->{GetNetworkInfo}->fault;
  } else {
    return $self->{GetNetworkInfo}->result;
  }
}

=head2 priv_GetWorkspaceByName

name string

=cut

sub priv_GetWorkspaceByName {
  my $self = shift @_;
  my $name = shift @_;
  
  $self->{GetWorkspaceByName} = 
    $self->{soap_priv}->GetWorkspaceByName(
      $self->{auth_header}, 
	  SOAP::Data->name('workspaceName'=>$name)->type('s:string')
	);

  $self->_fault( $self->{GetWorkspaceByName}->fault ) if $self->{GetWorkspaceByName}->fault;
  return $self->{GetWorkspaceByName}->result;
}

=head2 priv_LibraryCloneToWorkspace

public int LibraryCloneToWorkspace( 
int libraryId, 
int destWorkspaceId, 
bool isNewConfiguration, 
string newConfigName, 
string description, 
VMCopyData[] copyData, 
int existingConfigId, 
bool isFullClone, 
long storageLeaseInMilliseconds 
);

=cut

sub priv_LibraryCloneToWorkspace {
  my $self            = shift @_;
  my $libraryid       = shift @_;
  my $destworkspaceid = shift @_;
  my $isnew           = shift @_;
  my $newname         = shift @_;
  my $description     = shift @_;
  my $vmcopydata      = shift @_;
  my $existingconfid  = shift @_;
  my $isfullclone     = shift @_;
  my $storagelease    = shift @_;
  
  $self->{LibraryCloneToWorkspace} = 
    $self->{soap_priv}->LibraryCloneToWorkspace( $self->{auth_header}, 
	SOAP::Data->name('libraryId'                  => $libraryid       )->type('s:int'),
	SOAP::Data->name('destWorkspaceId'            => $destworkspaceid )->type('s:int'),
	SOAP::Data->name('isNewConfiguration'         => $isnew           )->type('s:boolean'),
	SOAP::Data->name('newConfigName'              => $newname         )->type('s:string'),
	SOAP::Data->name('description'                => $description     )->type('s:description'),
	SOAP::Data->name('existingConfigId'           => $existingconfid  )->type('s:int'),
	SOAP::Data->name('isFullClone'                => $isfullclone     )->type('s:boolean'),
	SOAP::Data->name('storageLeaseInMilliseconds' => $storagelease    )->type('s:long')
  );

#int libraryId, 
#int destWorkspaceId, 
#bool isNewConfiguration, 
#string newConfigName, 
#string description, 
#VMCopyData[] copyData, 
#int existingConfigId, 
#bool isFullClone, 
#long storageLeaseInMilliseconds 

  $self->_fault( $self->{LibraryCloneToWorkspace}->fault ) if $self->{LibraryCloneToWorkspace}->fault;
  return $self->{LibraryCloneToWorkspace}->result;
}

=head2 priv_ListTemplates

This method returns an array of type Machine. The method returns one Machine object for each virtual machine in a configuration.

=cut

sub priv_ListTemplates {
  my $self = shift @_;

  $self->_debug("LISTING TEMPLATES") if $self->{debug};

  my $lt = $self->{soap_priv}->ListTemplates( $self->{auth_header} );
  $self->_fault( $lt->fault ) if $lt->fault;

  my $ret = $lt->result;

  my $array = [ $ret ];
  $array = [ $ret->{Template} ] if ref $ret and ref $ret->{Template} eq 'HASH';
  $array =   $ret->{Template}   if ref $ret and ref $ret->{Template} eq 'ARRAY';

  if ( scalar(@$array) and $self->{debug} ) {
    $self->_debug('*'x20);
    for my $config (@$array) {
      for my $k ( sort keys(%$config) ) {
        $self->_debug("$k: $config->{$k}");
      }
      $self->_debug('*'x20);
    }
  }
  
  return wantarray ? @$array : $array;
}

=head2 priv_NetworkInterfaceCreate

=head3 Arguments

=over 4

=item * vmID - VM id number

=item * networkID

=item * IPAssignmentType

=item * IPAddress

=back

=cut

sub priv_NetworkInterfaceCreate {
  my $self   = shift @_;
  my $vmid   = shift @_;
  my $netid  = shift @_;
  my $iptype = shift @_;
  my $ipaddr = shift @_;

  $self->{NetworkInterfaceCreate} = 
    $self->{soap_priv}->NetworkInterfaceCreate(
      $self->{auth_header}, 
	  SOAP::Data->name('vmID'             =>$vmid   )->type('s:int'),
	  SOAP::Data->name('networkID'        =>$netid  )->type('s:int'),
	  SOAP::Data->name('IPAssignmentType' =>$iptype )->type('s:string'),
	  SOAP::Data->name('IPAddress'        =>$ipaddr )->type('s:string'),
	);

  if ( $self->{NetworkInterfaceCreate}->fault ) {
    $self->_fault( $self->{NetworkInterfaceCreate}->fault );
    return $self->{NetworkInterfaceCreate}->fault;
  } else {
    return $self->{NetworkInterfaceCreate}->result;
  }
}

=head2 priv_NetworkInterfaceDelete

=over 4

=item * vmID - VM id number

=item * nicID

=back

=cut

sub priv_NetworkInterfaceDelete {
  my $self  = shift @_;
  my $vmid  = shift @_;
  my $nicid = shift @_;

  $self->{NetworkInterfaceDelete} = 
    $self->{soap_priv}->NetworkInterfaceDelete(
      $self->{auth_header}, 
	  SOAP::Data->name('vmID'  => $vmid  )->type('s:int'),
	  SOAP::Data->name('nicID' => $nicid )->type('s:int'),
	);

  if ( $self->{NetworkInterfaceDelete}->fault ) {
    $self->_fault( $self->{NetworkInterfaceDelete}->fault );
    return $self->{NetworkInterfaceDelete}->fault;
  } else {
    return $self->{NetworkInterfaceDelete}->result;
  }
}

=head2 priv_StorageServerVMFSFindByName

=over 4

=item * Storename

=back

=cut

sub priv_StorageServerVMFSFindByName {
  my $self      = shift @_;
  my $storeName = shift @_;
  
  $self->{StorageServerVMFSFindByName} =
    $self->{soap_priv}->StorageServerVMFSFindByName(
					       $self->{auth_header},
					       SOAP::Data->name('name' => $storeName)->type(''));

  if ( $self->{StorageServerVMFSFindByName}->fault ) {
    $self->_fault( $self->{StorageServerVMFSFindByName}->fault );
    return $self->{StorageServerVMFSFindByName}->fault;
  } else {
    #return $self->{StorageServerVMFSFindByName}->result;
	my $result = $self->{StorageServerVMFSFindByName}->result;
	my $datastore = $$result{"label"}; # Need to be fixed. Currently in use?
	return $datastore;
  }
}

=head2 priv_TemplateImportFromSMB

=cut

sub priv_TemplateImportFromSMB {
  my $self        = shift @_;
  my $UNCPath     = shift @_;
  my $username    = shift @_;
  my $password    = shift @_;
  my $delete      = shift @_;
  my $description = shift @_;
  my $destStore   = shift @_;
  my $destName    = shift @_;
  my $destDesc    = shift @_;

 $self->{TemplateImportFromSMB} =
   $self->{soap_priv}->TemplateImportFromSMB(
     $self->{auth_header},

     SOAP::Data->name('name' => $destName)->type(''),
     SOAP::Data->name('VSTypeID' => $delete)->type(''),
     SOAP::Data->name('description' => $description)->type(''),
     SOAP::Data->name('storageServerName' => $destStore)->type(''),

     SOAP::Data->name('UNCPath' => $UNCPath)->type(''),
     SOAP::Data->name('dirUsername' => $username)->type(''),
     SOAP::Data->name('dirPassword' => $password)->type(''),

     SOAP::Data->name('performGuestCustomization' => "1")->type(''),

     SOAP::Data->name('parameterList' =>
       \SOAP::Data->value(

	 SOAP::Data->name('VMParameter' =>
	 \SOAP::Data->value(
	  SOAP::Data->name('parameter_name' => 'VCPUCOUNT')->type(''),
         SOAP::Data->name('parameter_value' => '4')->type(''))),

	 SOAP::Data->name('VMParameter' =>
	 \SOAP::Data->value(
	  SOAP::Data->name('parameter_name' => 'GUESTOS')->type(''),
         SOAP::Data->name('parameter_value' => 'RHEL4')->type(''))),

	 SOAP::Data->name('VMParameter' =>
	 \SOAP::Data->value(
	  SOAP::Data->name('parameter_name' => 'HW_VERSION')->type(''),
         SOAP::Data->name('parameter_value' => $7)->type(''))),


			  ))
				 );

  $self->_fault( $self->{TemplateImportFromSMB}->fault ) if $self->{TemplateImportFromSMB}->fault;
  return $self->{TemplateImportFromSMB}->result;
}

=head2 priv_TemplatePerformAction

=cut

sub priv_TemplatePerformAction {
  my $self        = shift @_;
  my $template_id = shift @_;
  my $action      = shift @_;
  
   $self->{TemplatePerformAction} =
     $self->{soap_priv}->TemplatePerformAction( $self->{auth_header},
                SOAP::Data->name('template_id'     => $template_id )->type('s:int'),
                SOAP::Data->name('action'          => $action      )->type('s:int') );
 
   if ($self->{TemplatePerformAction}->fault) {
     $self->_fault( $self->{TemplatePerformAction}->fault );
     return $self->{TemplatePerformAction}->fault;
   }
 
   return $self->{TemplatePerformAction}->result;
 }

=head2 priv_WorkspaceCreate

=head3 Arguments

=over 4

=item * name

=item * isMain

=item * description

=item * storedVMQuota

=item * deployedVMQuota

=back

=cut

sub priv_WorkspaceCreate {
  my $self        = shift @_;
  my $name        = shift @_;
  my $ismain      = shift @_;
  my $description = shift @_;
  my $storedquota = shift @_;
  my $deployquota = shift @_;
  
  $self->{WorkspaceCreate} = 
    $self->{soap_priv}->WorkspaceCreate( $self->{auth_header}, 
	SOAP::Data->name('name'            => $name        )->type('s:string'),
	SOAP::Data->name('isMain'          => $ismain      )->type('s:bool'),
	SOAP::Data->name('description'     => $description )->type('s:string'),
	SOAP::Data->name('storedVMQuota'   => $storedquota )->type('s:int'),
	SOAP::Data->name('deployedVMQuota' => $deployquota )->type('s:int') );

  $self->_fault( $self->{WorkspaceCreate}->fault ) if $self->{WorkspaceCreate}->fault;
  return $self->{WorkspaceCreate}->result;
}

return 1;

=head1 AUTHOR

 David F. Kinder, Jr, <dkinder@davidkinder.net>
 Phillip Pollard, <bennie@cpan.org>

=head1 CONTRIBUTIONS

 Cameron Berkenpas <cberkenpas@paypal.com>

=head1 DEPENDENCIES

 SOAP::Lite

=head1 SEE ALSO

VMWare Labmanger 
 http://www.vmware.com/products/labmanager/

VMWare Labmanager SOAP API Guide 
 http://www.vmware.com/pdf/lm40_soap_api_guide.pdf

VMWare Lab Manager: Automated Reconfiguration of Transiently Used Infrastructure 
 http://www.vmware.com/files/pdf/lm_whitepaper.pdf

=cut
