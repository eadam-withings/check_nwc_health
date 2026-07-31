package CheckNwcHealth::FSOS::Component::InterfaceSubsystem;
our @ISA = qw(CheckNwcHealth::IFMIB::Component::InterfaceSubsystem);
use strict;

sub enrich_interface_attributes {
  my ($self, $interface) = @_;
  # Preserve the *raw* ifAlias (OID 1.3.6.1.2.1.31.1.1.1.18) before the
  # generic IFMIB Interface::finish() overwrites an empty ifAlias with
  # ifName (see "$self->{ifAlias} ||= $self->{ifName};" in
  # CheckNwcHealth::IFMIB::Component::InterfaceSubsystem). Without this
  # override we could no longer tell whether the interface has a real
  # user-configured description.
  my $raw = $interface->{ifAlias};
  $raw = '' if ! defined $raw || $raw eq 'noSuchObject' || $raw eq 'noSuchInstance';
  $interface->{ifAliasRaw} = $raw;
  $self->SUPER::enrich_interface_attributes($interface);
}

sub check {
  my ($self) = @_;
  # For interface-health (device::interfaces::complete) on FSOS an interface
  # is considered "in error" only if:
  #   (ifOperStatus == down (OID 1.3.6.1.2.1.2.2.1.8 == 2)
  #    OR ifAdminStatus == down (OID 1.3.6.1.2.1.2.2.1.7 == 2))
  #   AND ifAlias (OID 1.3.6.1.2.1.31.1.1.1.18) is not empty.
  # Otherwise the interface is reported as OK. All other modes fall through
  # to the generic IFMIB implementation.
  if ($self->mode !~ /device::interfaces::complete/) {
    return $self->SUPER::check();
  }
  $self->add_info('checking interfaces');
  if (scalar(@{$self->{interfaces}}) == 0) {
    $self->add_unknown('no interfaces');
    return;
  }
  foreach my $if (sort {$a->{ifIndex} <=> $b->{ifIndex}} @{$self->{interfaces}}) {
    my $has_alias = defined($if->{ifAliasRaw})
        && $if->{ifAliasRaw} ne ''
        && $if->{ifAliasRaw} ne '0';
    my $is_down = ($if->{ifOperStatus} eq 'down'
        || $if->{ifAdminStatus} eq 'down');
    # Only "in error" interfaces produce output. All others are silently
    # considered healthy so the plugin output stays focused on real problems.
    next if ! ($is_down && $has_alias);
    my $msg = sprintf '%s (alias "%s") is %s/%s',
        $if->{ifDescr}, $if->{ifAliasRaw},
        $if->{ifOperStatus}, $if->{ifAdminStatus};
    $if->add_info($msg);
    $if->add_message(
        defined $if->opts->mitigation() ? $if->opts->mitigation() : 2,
        $msg);
  }
  $self->add_ok('all interfaces healthy') if ! $self->check_messages();
}


package CheckNwcHealth::FSOS::Component::InterfaceSubsystem::Interface;
our @ISA = qw(CheckNwcHealth::IFMIB::Component::InterfaceSubsystem::Interface);
use strict;

1;
