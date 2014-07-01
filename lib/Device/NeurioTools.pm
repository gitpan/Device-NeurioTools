package Device::NeurioTools;

use warnings;
use strict;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Device::NeurioTools ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
    new connect set_rate get_cost get_kwh
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw();

BEGIN
{
  if ($^O eq "MSWin32"){
    use Device::Neurio;
    use Time::Local;
    use DateTime::Format::ISO8601;
    use Data::Dumper;
  } else {
    use Device::Neurio;
    use Time::Local;
    use DateTime::Format::ISO8601;
    use Data::Dumper;
  }
}


=head1 NAME

Device::NeurioTools - More complex methods for accessing data collected by a Neurio sensor module.

=head1 VERSION

Version 0.03

=cut

our $VERSION = '0.03';

#*****************************************************************

=head1 SYNOPSIS

 This module allows access to more complex and detailed data derived from data 
 collected by a Neurio sensor.  This is done via an extended set of methods: 
   - new
   - connect
   - set_rate
   - get_cost
   - get_kwh
  
 Please note that in order to use this module you will require three parameters
 (key, secret, sensor_id) as well as an Energy Aware Neurio sensor installed in
 your house.

 The module is written entirely in Perl and has been tested on Raspbian Linux.


=head1 SAMPLE CODE


=head2 EXPORT

All by default.


#*****************************************************************

=head2 new - the constructor for a NeurioTools object

 Creates a new instance which will be able to fetch data from a unique Neurio 
 sensor.

 my $Neurio = Device::NeurioTools->new($key,$secret,$sensor_id);

   This method accepts the following parameters:
     - $key       : unique key for the account - Required parameter
     - $secret    : secret key for the account - Required parameter
     - $sensor_id : sensor ID connected to the account - Required parameter

 Returns a NeurioTools object if successful.
 Returns 0 on failure
=cut
sub new {
    my $class = shift;
    my $self;

    $self->{'key'}       = shift;
    $self->{'secret'}    = shift;
    $self->{'sensor_id'} = shift;
	$self->{'rate'}      = 0;
    
    if ((!defined $self->{'key'}) || (!defined $self->{'secret'}) || (!defined $self->{'sensor_id'})) {
      print "NeurioTools->new(): Key, Secret and Sensor_ID are REQUIRED parameters.\n";
      return 0;
    }

    $self->{'neurio'} = Device::Neurio->new($self->{'key'},$self->{'secret'},$self->{'sensor_id'});
    
    bless $self, $class;
    
    return $self;
}


#*****************************************************************

=head2 connect - open a secure connection to the Neurio server

 Opens a secure connection via HTTPS to the Neurio server which provides
 access to a set of API commands to access the sensor data.

   $NeurioTools->connect();
 
 This method accepts no parameters
 
 Returns 1 on success 
 Returns 0 on failure
=cut
sub connect {
	my $self = shift;
    
    if($self->{'neurio'}->connect()) {
      return 1;
    } else {
      print "NeurioTools->connect(): Failed to connect.\n";
      return 0;
    }
}

#*****************************************************************

=head2 set_rate - set the rate charged by your electicity provider

 Defines the rate charged by your electricity provider.

   $NeurioTools->set_rate($rate);
 
   This method accepts the following parameters:
     - $rate      : amount charged per kwh - Required
 
 Returns 1 on success 
 Returns 0 on failure
=cut
sub set_rate {
	my ($self,$rate) = @_;
	
    if (defined $rate) {
	  $self->{'rate'} = $rate;
      print "NeurioTools->set_rate(): $self->{'rate'}\n";
	  return 1;
    } else {
      print "NeurioTools->set_rate(): No rate specified\n";
      return 0;
    }
}


#*****************************************************************

=head2 get_rate - return the rate charged by your electicity provider

 Returns the value for rate set using 'set_rate()'

   $NeurioTools->get_rate();
 
   This method accepts no parameters
 
 Returns rate 
=cut
sub get_rate {
	my $self = shift;
    return $self->{'rate'};
}


#*****************************************************************

=head2 set_timezone - set the timezone offset

 Sets the timezone offset.  If no parameter is specified it uses the system
 defined timezone offset.

   $NeurioTools->set_timezone($offset);
 
   This method accepts the following parameters:
     - $offset      : specified timezone offset in minutes - Optional
 
 Returns 1 on success 
 Returns 0 on failure
=cut
sub set_timezone {
	my ($self,$offset) = @_;
	my ($total,$hours,$mins);
	
    if (defined $offset) {
	  $total = $offset;
    } else {
      my @utc   = gmtime();
      my @loc   = localtime();
      $total = ($loc[2]*60+$loc[1])-($utc[2]*60+$utc[1]);
    }
    $hours = sprintf("%+03d",$total / 60);
    $mins  = sprintf("%02d",$total % 60);
    $self->{'timezone'} = "$hours:$mins";
    print "NeurioTools->set_timezone(): $self->{'timezone'}\n";
    
    return 1;
}


#*****************************************************************

=head2 get_timezone - return the timezone offset

 Returns the value for the timezone offset in minutes

   $NeurioTools->get_timezone();
 
   This method accepts no parameters
 
 Returns timezone offset 
=cut
sub get_timezone {
	my $self = shift;
	
    return $self->{'timezone'};
}


#*****************************************************************

=head2 get_cost - calculate the cost of consumption for the specified period

 Calculates the cost of consumption over the period specified.

   $NeurioTools->get_cost($start,$granularity,$end,$frequency);
 
   This method accepts the following parameters:
     - start       : yyyy-mm-ddThh:mm:ssZ - Required
     - granularity : seconds|minutes|hours|days - Required
     - end         : yyyy-mm-ddThh:mm:ssZ - Optional
     - frequency   : an integer - Optional
 
 Returns the cost on success 
 Returns 0 on failure
=cut
sub get_cost {
    my ($self,$start,$granularity,$end,$frequency) = @_;
    my $i=0;
    
    if ($self->{'rate'} ==0 ) {
        print "NeurioTools->get_cost(): Cannot calculate cost since rate is set to zero\n";
        return 0;
    }
    
    my $kwh  = $self->get_kwh($start,$granularity,$end,$frequency);
    my $cost = $kwh*$self->{'rate'};
    
    return $cost;
}


#*****************************************************************

=head2 get_kwh - calculate the kwh of consumption for the specified period

 Calculates the kwh of consumption over the period specified.

   $NeurioTools->get_kwh($start,$granularity,$end,$frequency);
 
   This method accepts the following parameters:
     - start       : yyyy-mm-ddThh:mm:ssZ - Required
                     specified using ISO8601 format
     - granularity : seconds|minutes|hours|days - Required
     - end         : yyyy-mm-ddThh:mm:ssZ - Optional
                     specified using ISO8601 format
     - frequency   : an integer - Optional
 
 Returns the kwh on success 
 Returns 0 on failure
=cut
sub get_kwh {
    my ($self,$start,$granularity,$end,$frequency) = @_;
    my $samples = 0;
    my $power   = 0;
    my $kwh;
    
    my $data = $self->{'neurio'}->fetch_Samples($start,$granularity,$end,$frequency);
    
    my $start_obj = DateTime::Format::ISO8601->parse_datetime($start);
    my $end_obj   = DateTime::Format::ISO8601->parse_datetime($end);
    my $dur_obj   = $end_obj->subtract_datetime($start_obj);
    my $duration  = eval($dur_obj->{'minutes'}*60+$dur_obj->{'seconds'});
    while (defined $data->[$samples]->{'consumptionPower'}) {
        $power=$power+$data->[$samples]->{'consumptionPower'};
        $samples++;
    }
    
    $kwh = $power/1000*$duration/60/60/$samples;

    return $kwh;
}


#*****************************************************************

=head1 AUTHOR

Kedar Warriner, C<kedar at cpan.org>

=head1 BUGS

 Please report any bugs or feature requests to C<bug-device-NeurioTools at rt.cpan.org>
 or through the web interface at http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Device-NeurioTools
 I will be notified, and then you'll automatically be notified of progress on 
 your bug as I make changes.


=head1 SUPPORT

 You can find documentation for this module with the perldoc command.

  perldoc Device::NeurioTools


 You can also look for information at:

=over 5

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Device-NeurioTools>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Device-NeurioTools>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Device-NeurioTools>

=item * Search CPAN

L<http://search.cpan.org/dist/Device-NeurioTools/>

=back


=head1 ACKNOWLEDGEMENTS

 Many thanks to:
  The guys at Energy Aware Technologies for creating the Neurio sensor and 
      developping the API.
  Everyone involved with CPAN.

=head1 LICENSE AND COPYRIGHT

 Copyright 2014 Kedar Warriner <kedar at cpan.org>.

 This program is free software; you can redistribute it and/or modify it
 under the terms of either: the GNU General Public License as published
 by the Free Software Foundation; or the Artistic License.

 See http://dev.perl.org/licenses/ for more information.


=cut

#************************************************************************
1; # End of Device::NeurioTools - Return success to require/use statement
#************************************************************************

