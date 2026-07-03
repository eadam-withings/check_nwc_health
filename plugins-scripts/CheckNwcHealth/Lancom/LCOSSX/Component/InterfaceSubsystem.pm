package CheckNwcHealth::Lancom::LCOSSX::Component::InterfaceSubsystem;
our @ISA = qw(CheckNwcHealth::IFMIB::Component::InterfaceSubsystem);
use strict;

sub enrich_interface_cache {
  my ($self) = @_;
  # LCOS-SX-MIB::lcsPortConfigurationTable augments ifTable: its row index
  # is the same number as ifIndex. Copy the port-configuration description
  # into the matching cache entry so it becomes selectable via
  # --name3 lcsPortConfDescription::<value> and displayable in
  # device::interfaces::list, without any extra SNMP round-trip at filter
  # time.
  $self->get_snmp_tables('LCOS-SX-MIB', [
    ['lcsportconf', 'lcsPortConfigurationTable', 'CheckNwcHealth::Lancom::LCOSSX::Component::InterfaceSubsystem::PortConf', undef, ['lcsPortConfDescription']],
  ]);
  foreach my $lcsportconf (@{$self->{lcsportconf}}) {
    my $index = $lcsportconf->{lcsPortConfPort};
    if (exists $self->{interface_cache}->{$index}) {
      $self->{interface_cache}->{$index}->{lcsPortConfDescription} =
          $lcsportconf->{lcsPortConfDescription};
    }
    # rows whose index has no matching known interface are skipped on
    # purpose - they would otherwise create a bogus, incomplete cache entry
  }
}

sub enrich_interface_attributes {
  my ($self, $interface) = @_;
  if (exists $self->{interface_cache}->{$interface->{flat_indices}}->{lcsPortConfDescription}) {
    $interface->{lcsPortConfDescription} =
        $self->{interface_cache}->{$interface->{flat_indices}}->{lcsPortConfDescription};
  }
}

# lcsPortConfPort is the table's own INDEX column and is not-accessible -
# confirmed against a real device capture, where a walk only ever returns
# lcsPortConfDescription - so the port number has to be derived from the
# response's own row index instead of being fetched as a column value.
package CheckNwcHealth::Lancom::LCOSSX::Component::InterfaceSubsystem::PortConf;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  $self->ensure_index('lcsPortConfPort');
  return $self;
}

# eigentlich unnoetig, aber CheckNwcHealth::IFMIB::Component::InterfaceSubsystem
# blesst ref($self)::Interface
package CheckNwcHealth::Lancom::LCOSSX::Component::InterfaceSubsystem::Interface;
our @ISA = qw(CheckNwcHealth::IFMIB::Component::InterfaceSubsystem::Interface);
use strict;

sub list {
  my ($self) = @_;
  if ($self->mode =~ /device::interfaces::listdetail/) {
    $self->SUPER::list();
  } else {
    # ifDescr is free text and may itself contain spaces (e.g. "Switch  1 -
    # Port 19"), so the vendor label is shown behind an explicit label
    # instead of being appended as a bare trailing string - otherwise a
    # user can't tell where ifDescr ends and lcsPortConfDescription begins,
    # which defeats the point of this listing (finding the exact value to
    # pass to --name3 lcsPortConfDescription::<value>).
    printf "%06d %s%s\n", $self->{ifIndex}, $self->{ifDescr},
        defined $self->{lcsPortConfDescription} ?
            sprintf(' [lcsPortConfDescription: %s]', $self->{lcsPortConfDescription}) : '';
  }
}

package CheckNwcHealth::Lancom::LCOSSX::Component::InterfaceSubsystem::Interface::64bit;
our @ISA = qw(CheckNwcHealth::IFMIB::Component::InterfaceSubsystem::Interface::64bit);
use strict;
