package CheckNwcHealth::FSOS::Component::DiskSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my ($self) = @_;
  my $index = 1;
  $self->{fsDiskTotal} = $self->get_snmp_object(
      'FIBERSTORE-PRODUCTS-MIB', 'fsDiskTotal', $index);
  $self->{fsDiskFree} = $self->get_snmp_object(
      'FIBERSTORE-PRODUCTS-MIB', 'fsDiskFree', $index);
  $self->{fsDiskMount} = $self->get_snmp_object(
      'FIBERSTORE-PRODUCTS-MIB', 'fsDiskMount', $index);
  $self->{fsDiskDescr} = $self->get_snmp_object(
      'FIBERSTORE-PRODUCTS-MIB', 'fsDiskDescr', $index);
}

sub check {
  my ($self) = @_;
  if (defined $self->{fsDiskTotal} && defined $self->{fsDiskFree}) {
    my $total = $self->parse_disk_size($self->{fsDiskTotal});
    my $free = $self->parse_disk_size($self->{fsDiskFree});
    my $used = $total - $free;
    if ($total > 0) {
      my $usage = ($used / $total) * 100;
      $self->add_info(sprintf 'Disk %s usage is %.2f%%',
          $self->{fsDiskMount} || 'unknown', $usage);
      my $label = 'disk_usage';
      if ($self->{fsDiskMount}) {
        $label = sprintf 'disk_%s_usage', $self->{fsDiskMount};
        $label =~ s/[\/:]/_/g;
      }
      $self->set_thresholds(metric => $label, warning => 80, critical => 90);
      $self->add_message($self->check_thresholds(
          metric => $label, value => $usage));
      $self->add_perfdata(
          label => $label,
          value => $usage,
          uom => '%',
      );
    }
  } else {
    $self->add_unknown('Cannot read disk usage');
  }
}

sub parse_disk_size {
  my ($self, $size_str) = @_;
  my $size = 0;
  if ($size_str =~ /^([\d.]+)([KMGTP]?)/) {
    my $value = $1;
    my $unit = $2;
    if ($unit eq 'K') {
      $size = $value * 1024;
    } elsif ($unit eq 'M') {
      $size = $value * 1024 * 1024;
    } elsif ($unit eq 'G') {
      $size = $value * 1024 * 1024 * 1024;
    } elsif ($unit eq 'T') {
      $size = $value * 1024 * 1024 * 1024 * 1024;
    } else {
      $size = $value;
    }
  }
  return $size;
}
