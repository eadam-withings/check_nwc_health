package CheckNwcHealth::FSOS::Component::CpuSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my ($self) = @_;
  $self->get_snmp_objects('FIBERSTORE-PRODUCTS-MIB', qw(fsCpuUsage));
}

sub check {
  my ($self) = @_;
  if (defined $self->{fsCpuUsage} && $self->{fsCpuUsage} =~ /\d/) {
    my $cpu_usage = $self->{fsCpuUsage} * 1.0;
    $self->add_info(sprintf 'CPU usage is %.2f%%', $cpu_usage);
    my $label = 'cpu_usage';
    $self->set_thresholds(metric => $label, warning => 80, critical => 90);
    $self->add_message($self->check_thresholds(
        metric => $label, value => $cpu_usage));
    $self->add_perfdata(
        label => $label,
        value => $cpu_usage,
        uom => '%',
    );
  } else {
    $self->add_unknown('Cannot read CPU usage');
  }
}
