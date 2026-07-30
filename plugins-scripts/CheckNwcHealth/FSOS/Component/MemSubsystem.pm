package CheckNwcHealth::FSOS::Component::MemSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my ($self) = @_;
  $self->get_snmp_objects('FIBERSTORE-PRODUCTS-MIB', qw(
      fsMemTotal fsMemUsed fsMemFree
      fsMemUsagePct fsMemWarnThreshold fsMemCritThreshold));
}

sub check {
  my ($self) = @_;
  my $mem_usage = undef;
  my $warn = $self->{fsMemWarnThreshold} || 80;
  my $crit = $self->{fsMemCritThreshold} || 90;
  if (defined $self->{fsMemUsagePct} && $self->{fsMemUsagePct} =~ /([\d.]+)%/) {
    $mem_usage = $1 * 1.0;
  } elsif (defined $self->{fsMemTotal} && $self->{fsMemTotal} > 0 &&
           defined $self->{fsMemUsed}) {
    $mem_usage = ($self->{fsMemUsed} / $self->{fsMemTotal}) * 100;
  }
  if (defined $mem_usage) {
    $self->add_info(sprintf 'Memory usage is %.2f%%', $mem_usage);
    my $label = 'memory_usage';
    $self->set_thresholds(metric => $label, warning => $warn, critical => $crit);
    $self->add_message($self->check_thresholds(
        metric => $label, value => $mem_usage));
    $self->add_perfdata(
        label => $label,
        value => $mem_usage,
        uom => '%',
    );
  } else {
    $self->add_unknown('Cannot read memory usage');
  }
}
