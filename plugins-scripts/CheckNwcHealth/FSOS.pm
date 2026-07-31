package CheckNwcHealth::FSOS;
our @ISA = qw(CheckNwcHealth::Device);
use strict;

sub init {
  my ($self) = @_;
  my $mode = $self->mode;
  if ($mode =~ /device::hardware::load|cpu-load|cpu-usage/) {
    $self->analyze_and_check_cpu_subsystem("CheckNwcHealth::FSOS::Component::CpuSubsystem");
  } elsif ($mode =~ /device::hardware::memory|memory-usage/) {
    $self->analyze_and_check_mem_subsystem("CheckNwcHealth::FSOS::Component::MemSubsystem");
  } elsif ($mode =~ /device::disk::usage|disk-usage/) {
    $self->analyze_and_check_disk_subsystem("CheckNwcHealth::FSOS::Component::DiskSubsystem");
  } elsif ($mode =~ /device::hardware::health|hardware-health/) {
    $self->analyze_and_check_environmental_subsystem("CheckNwcHealth::FSOS::Component::EnvironmentalSubsystem");
  } elsif ($mode =~ /device::interfaces|interface-usage/) {
    $self->analyze_and_check_interface_subsystem("CheckNwcHealth::FSOS::Component::InterfaceSubsystem");
  } else {
    $self->no_such_mode();
  }
}
