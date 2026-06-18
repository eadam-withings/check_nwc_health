package CheckNwcHealth::IPMIB::Component::RoutingSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my ($self) = @_;
  $self->{interfaces} = [];
  $self->get_snmp_tables('IP-MIB', [
      ['routes', 'ipRouteTable', 'CheckNwcHealth::IPMIB::Component::RoutingSubsystem::Route',
          sub {
            # The legacy ipRouteTable path must honour --name/--name2 exactly
            # like the IP-FORWARD-MIB path does. Without this filter callback
            # every row was loaded unconditionally and --name was silently
            # ignored (mirrors the ipCidrRouteTable callback in IPFORWARDMIB).
            my ($o) = @_;
            if ($o->opts->name && $o->opts->name =~ /\//) {
              # --name given as address/prefix: match the destination address
              # and the netmask derived from the prefix length.
              my ($dest, $cidr) = split(/\//, $o->opts->name);
              my $bits = ( 2 ** (32 - $cidr) ) - 1;
              my ($full_mask) = unpack("N", pack("C4", split(/\./, '255.255.255.255')));
              my $netmask = join('.', unpack("C4", pack("N", ($full_mask ^ $bits))));
              return defined $o->{ipRouteDest} && (
                  $o->filter_namex($dest, $o->{ipRouteDest}) &&
                  $o->filter_namex($netmask, $o->{ipRouteMask}) &&
                  $o->filter_name2($o->{ipRouteNextHop})
              );
            } else {
              return defined $o->{ipRouteDest} && (
                  $o->filter_name($o->{ipRouteDest}) &&
                  $o->filter_name2($o->{ipRouteNextHop})
              );
            }
          }
      ],
  ]);
}

sub check {
  my ($self) = @_;
  $self->add_info('checking routes');
  if ($self->mode =~ /device::routes::list/) {
    foreach (@{$self->{routes}}) {
      $_->list();
    }
    $self->add_ok("have fun");
  } elsif ($self->mode =~ /device::routes::count/) {
    if (! $self->opts->name && $self->opts->name2) {
      $self->add_info(sprintf "found %d routes via next hop %s",
          scalar(@{$self->{routes}}), $self->opts->name2);
    } elsif ($self->opts->name && ! $self->opts->name2) {
      $self->add_info(sprintf "found %d routes to dest %s",
          scalar(@{$self->{routes}}), $self->opts->name);
    } elsif ($self->opts->name && $self->opts->name2) {
      $self->add_info(sprintf "found %d routes to dest %s via hop %s",
          scalar(@{$self->{routes}}), $self->opts->name, $self->opts->name2);
    } else {
      $self->add_info(sprintf "found %d routes",
          scalar(@{$self->{routes}}));
    }
    $self->set_thresholds(warning => '1:', critical => '1:');
    $self->add_message($self->check_thresholds(scalar(@{$self->{routes}})));
    $self->add_perfdata(
        label => 'routes',
        value => scalar(@{$self->{routes}}),
    );
  }
}


package CheckNwcHealth::IPMIB::Component::RoutingSubsystem::Route;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);

# Print one route per line using the same column layout as the IP-FORWARD-MIB
# RoutingSubsystem listing, so list-routes output is consistent across both
# route paths instead of falling back to a generic attribute dump.
sub list {
  my ($self) = @_;
  printf "%16s %16s %16s %11s %7s\n",
      $self->{ipRouteDest}, $self->{ipRouteMask},
      $self->{ipRouteNextHop}, $self->{ipRouteProto},
      $self->{ipRouteType};
}

