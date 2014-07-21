package Device::NeurioTools;

use warnings;
use strict;
use 5.006_001; 

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Device::NeurioTools ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.

our %EXPORT_TAGS = ( 'all' => [ qw(
    new get_flat_cost get_energy_consumed get_kwh_consumed get kwh_generated get_power_consumed get_flat_rate get_timezone set_flat_rate set_timezone
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

Device::NeurioTools - More complex methods for accessing data collected by a 
                      Neurio sensor module.

=head1 VERSION

Version 0.06

=cut

our $VERSION = '0.06';

#*****************************************************************

=head1 SYNOPSIS

 This module allows access to more complex and detailed data derived from data 
 collected by a Neurio sensor.  This is done via an extended set of methods: 
   - new
   - connect
   - set_flat_rate
   - get_flat_rate
   - get_flat_cost
   - get_kwh
  
 Please note that in order to use this module you will require three parameters
 (key, secret, sensor_id) as well as an Energy Aware Neurio sensor installed in
 your house.

 The module is written entirely in Perl and has been developped on Raspbian Linux.


=head1 SAMPLE CODE

    use Device::Neurio;
    use Device::NeurioTools;

    $my_Neurio = Device::Neurio->new($key,$secret,$sensor_id);

    $my_Neurio->connect();

    $my_NeurioTools = Device::NeurioTools->new($my_Neurio,$debug);

    $my_NeurioTools->set_timezone();
    $my_NeurioTools->set_flat_rate(0.08);
    
    $start = "2014-06-24T00:00:00".$my_NeurioTools->get_timezone();
    $end   = "2014-06-24T23:59:59".$my_NeurioTools->get_timezone();
    $kwh   = $my_NeurioTools->get_kwh($start,"minutes",$end,"5");

    undef $my_NeurioTools;
    undef $my_Neurio;

=head2 EXPORT

All by default.


#*****************************************************************

=head2 new - the constructor for a NeurioTools object

 Creates a new instance of NeurioTools which will be able to fetch data from 
 a unique Neurio sensor.

 my $Neurio = Device::NeurioTools->new($neurio, $debug);

   This method accepts the following parameters:
     - $neurio : a valid CONNECTED Neurio object
     - $debug  : enable or disable debug messages (disabled by default - optional)

 Returns 1 on success
 Returns 0 on failure
=cut
sub new {
    my $class = shift;
    my $self;

    $self->{'neurio'}    = shift;
    $self->{'debug'}     = shift;
	$self->{'flat_rate'} = 0;
	$self->{'timezone'}  = "+00:00";
    
    if (!defined $self->{'debug'}) {
      $self->{'debug'} = 0;
    }
    
    if (!defined $self->{'neurio'}) {
      print "NeurioTools->new(): a valid Neurio object is a REQUIRED parameter.\n";
      return 0;
    }
    
    bless $self, $class;
    
    return $self;
}


#*****************************************************************

=head2 set_flat_rate - set the rate charged by your electicity provider

 Defines the rate charged by your electricity provider.

   $NeurioTools->set_flat_rate($rate);
 
   This method accepts the following parameters:
     - $rate      : amount charged per kwh - Required
 
 Returns 1 on success 
 Returns 0 on failure
=cut
sub set_flat_rate {
	my ($self,$rate) = @_;
	
    if (defined $rate) {
	  $self->{'flat_rate'} = $rate;
      print "NeurioTools->set_flat_rate(): $self->{'flat_rate'}\n" if ($self->{'debug'});
	  return 1;
    } else {
      print "NeurioTools->set_flat_rate(): No rate specified\n";
      return 0;
    }
}


#*****************************************************************

=head2 get_flat_rate - return the rate charged by your electicity provider

 Returns the value for rate set using 'set_flat_rate()'

   $NeurioTools->get_flat_rate();
 
   This method accepts no parameters
 
 Returns rate 
=cut
sub get_flat_rate {
	my $self = shift;
    return $self->{'flat_rate'};
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
      my @utc = gmtime();
      my @loc = localtime();
      $total  = ($loc[2]*60+$loc[1])-($utc[2]*60+$utc[1]);
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

=head2 get_flat_cost - calculate the cost of consumed power for the specified period

 Calculates the cost of consumed power over the period specified.

   $NeurioTools->get_flat_cost($start,$granularity,$end,$frequency);
   
   This method requires that a 'flat rate' be set using the set_flat_rate() method
 
   This method accepts the following parameters:
     - start       : yyyy-mm-ddThh:mm:ssZ - Required
     - granularity : seconds|minutes|hours|days - Required
     - end         : yyyy-mm-ddThh:mm:ssZ - Optional
     - frequency   : an integer - Optional
 
 Returns the cost on success 
 Returns 0 on failure
=cut
sub get_flat_cost {
    my ($self,$start,$granularity,$end,$frequency) = @_;
    my $i=0;
    
    if ($self->{'flat_rate'} == 0 ) {
        print "NeurioTools->get_flat_cost(): Cannot calculate cost since rate is set to zero\n";
        return 0;
    }
    
    my $kwh  = $self->get_kwh_consumed($start,$granularity,$end,$frequency);
    my $cost = $kwh*$self->{'flat_rate'};
    
    return $cost;
}


#*****************************************************************

=head2 get_kwh_consumed - kwh of consumed power for the specified period

 Calculates the total kwh of consumed power over the period specified.

   $NeurioTools->get_kwh_consumed($start,$granularity,$end,$frequency);
 
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
sub get_kwh_consumed {
    my ($self,$start,$granularity,$end,$frequency) = @_;
    my $energy  = 0;
    my $samples = 0;
    my $kwh;
    
    my $data      = $self->{'neurio'}->fetch_Energy_Stats($start,$granularity,$end,$frequency,"1","5000");
    my $start_obj = DateTime::Format::ISO8601->parse_datetime($start);
    my $end_obj   = DateTime::Format::ISO8601->parse_datetime($end);
    my $dur_obj   = $end_obj->subtract_datetime($start_obj);
    my $duration  = eval($dur_obj->{'minutes'}*60+$dur_obj->{'seconds'});
    
    while (defined $data->[$samples]->{'consumptionEnergy'}) {
        $energy = $energy + $data->[$samples]->{'consumptionEnergy'};
        $samples++;
    }
    
    $kwh = $energy/(1000*3600);

    return $kwh;
}


#*****************************************************************

=head2 get_kwh_generated - kwh of generated power for the specified period

 Calculates the total kwh of generated power over the period specified.

   $NeurioTools->get_kwh_generated($start,$granularity,$end,$frequency);
 
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
sub get_kwh_generated {
    my ($self,$start,$granularity,$end,$frequency) = @_;
    my $samples = 0;
    my $power   = 0;
    my $kwh;
    
    my $data      = $self->{'neurio'}->fetch_Samples($start,$granularity,$end,$frequency);
    my $start_obj = DateTime::Format::ISO8601->parse_datetime($start);
    my $end_obj   = DateTime::Format::ISO8601->parse_datetime($end);
    my $dur_obj   = $end_obj->subtract_datetime($start_obj);
    my $duration  = eval($dur_obj->{'minutes'}*60+$dur_obj->{'seconds'});
    
    while (defined $data->[$samples]->{'generationPower'}) {
        $power = $power + $data->[$samples]->{'generationPower'};
        $samples++;
    }
    
    $kwh = $power/1000*$duration/60/60/$samples;

    return $kwh;
}


#*****************************************************************

=head2 get_energy_consumed - energy consumed for the specified period

 Calculates the total energy consumed over the period specified.

   $NeurioTools->get_energy_consumed($start,$granularity,$end,$frequency);
 
   This method accepts the following parameters:
     - start       : yyyy-mm-ddThh:mm:ssZ - Required
                     specified using ISO8601 format
     - granularity : seconds|minutes|hours|days - Required
     - end         : yyyy-mm-ddThh:mm:ssZ - Optional
                     specified using ISO8601 format
     - frequency   : an integer - Optional
 
 Returns the energy on success 
 Returns 0 on failure
=cut
sub get_energy_consumed {
    my ($self,$start,$granularity,$end,$frequency) = @_;
    my $samples = 0;
    my $energy   = 0;
    my $kwh;
    
    my $data      = $self->{'neurio'}->fetch_Samples($start,$granularity,$end,$frequency);
    my $start_obj = DateTime::Format::ISO8601->parse_datetime($start);
    my $end_obj   = DateTime::Format::ISO8601->parse_datetime($end);
    my $dur_obj   = $end_obj->subtract_datetime($start_obj);
    my $duration  = eval($dur_obj->{'minutes'}*60+$dur_obj->{'seconds'});
    
    while (defined $data->[$samples]->{'consumptionEnergy'}) {
        $energy = $energy + $data->[$samples]->{'consumptionEnergy'};
        $samples++;
    }
    
    return $energy;
}


#*****************************************************************

=head2 get_power_consumed - power consumed for the specified period

 Calculates the total power  consumed over the period specified.

   $NeurioTools->get_energy_consumed($start,$granularity,$end,$frequency);
 
   This method accepts the following parameters:
     - start       : yyyy-mm-ddThh:mm:ssZ - Required
                     specified using ISO8601 format
     - granularity : seconds|minutes|hours|days - Required
     - end         : yyyy-mm-ddThh:mm:ssZ - Optional
                     specified using ISO8601 format
     - frequency   : an integer - Optional
 
 Returns the energy on success 
 Returns 0 on failure
=cut
sub get_power_consumed {
    my ($self,$start,$granularity,$end,$frequency) = @_;
    my $samples = 0;
    my $power   = 0;
    
    my $data      = $self->{'neurio'}->fetch_Samples($start,$granularity,$end,$frequency);
    my $start_obj = DateTime::Format::ISO8601->parse_datetime($start);
    my $end_obj   = DateTime::Format::ISO8601->parse_datetime($end);
    my $dur_obj   = $end_obj->subtract_datetime($start_obj);
    my $duration  = eval($dur_obj->{'minutes'}*60+$dur_obj->{'seconds'});
    
    while (defined $data->[$samples]->{'consumptionPower'}) {
        $power = $power + $data->[$samples]->{'consumptionPower'};
        $samples++;
    }
    
    return $power;
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

