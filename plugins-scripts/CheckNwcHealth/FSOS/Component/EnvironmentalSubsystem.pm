package CheckNwcHealth::FSOS::Component::EnvironmentalSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

# FSOS environmental subsystem.

sub init {
  my ($self) = @_;

  $self->get_snmp_tables('FIBERSTORE-PRODUCTS-MIB', [
      ['fans',  'fsFanTable',  'CheckNwcHealth::FSOS::Component::EnvironmentalSubsystem::FanRotor'],
      ['psus',  'fsPsuTable',  'CheckNwcHealth::FSOS::Component::EnvironmentalSubsystem::PowerSupply'],
      ['temps', 'fsTempTable', 'CheckNwcHealth::FSOS::Component::EnvironmentalSubsystem::TempSensor'],
  ]);

  if (@{$self->{fans}} || @{$self->{psus}} || @{$self->{temps}}) {
    $self->{have_fsos_dc} = 1;
  }
}

sub check {
  my ($self) = @_;

  if (! $self->{have_fsos_dc}) {
    $self->add_unknown('no environmental sensors found');
    return;
  }

  # Fan trays: group rotors by tray, tray CRITICAL if any rotor status != ok
  my %trays;
  foreach my $rotor (@{$self->{fans}}) {
    my $tray = $rotor->{fsFanTrayIndex} // '?';
    push @{$trays{$tray}}, $rotor;
  }
  foreach my $tray (sort { $a <=> $b } keys %trays) {
    my @faulty = grep {
      defined $_->{fsFanStatus} && $_->{fsFanStatus} ne 'ok'
    } @{$trays{$tray}};
    if (@faulty) {
      my $desc = join(',', map {
        sprintf('rotor%s=%s', $_->{fsFanRotorIndex} // '?', $_->{fsFanStatus} // '?')
      } @faulty);
      $self->add_critical(sprintf('fan tray %s faulty (%s)', $tray, $desc));
    } else {
      $self->add_ok(sprintf('fan tray %s ok', $tray));
    }
    foreach my $rotor (@{$trays{$tray}}) {
      my $pct = $rotor->{fsFanSpeedPct};
      if (defined $pct && $pct =~ /(-?\d+(?:\.\d+)?)/) {
        $self->add_perfdata(
          label => sprintf('fan_tray%s_rotor%s', $tray, $rotor->{fsFanRotorIndex} // '?'),
          value => $1,
          uom   => '%',
        );
      }
    }
  }

  # PSUs: OK only if present=present AND state=ok AND powered=powered
  foreach my $psu (@{$self->{psus}}) {
    my $idx = $psu->{flat_indices} // '?';
    my $pres = $psu->{fsPsuPresent}  // '?';
    my $st   = $psu->{fsPsuState}    // '?';
    my $pow  = $psu->{fsPsuPowered}  // '?';
    if ($pres eq 'present' && ($st eq 'AC' || $st eq 'DC') && $pow eq 'powered') {
      $self->add_ok(sprintf('psu %s ok (%s)', $idx, $st));
    } else {
      $self->add_critical(sprintf(
        'psu %s faulty (present=%s,state=%s,powered=%s)',
        $idx, $pres, $st, $pow));
    }
    if (defined $psu->{fsPsuCurrentPower} && $psu->{fsPsuCurrentPower} =~ /^\d+$/) {
      $self->add_perfdata(
        label => sprintf('psu%s_pwr', $idx),
        value => $psu->{fsPsuCurrentPower},
      );
    }
  }

  # Temperature: default warn 65 / crit 80, overridable per-metric
  foreach my $t (@{$self->{temps}}) {
    my $idx = $t->{flat_indices} // '?';
    my $c   = $t->{fsTempCurrent};
    next if ! defined $c;
    my $metric = sprintf('temp_sensor_%s', $idx);
    $self->set_thresholds(metric => $metric, warning => 65, critical => 80);
    my ($w, $cr) = $self->get_thresholds(metric => $metric);
    my $level = $self->check_thresholds(value => $c, metric => $metric);
    my $pos = "unknown";
    if ($idx == 1) {
      $pos = "AROUND_CHIP";
    } elsif ($idx == 2) {
      $pos = "SWITCH_CHIP";
    }
    $self->add_message($level, sprintf('temp sensor %s (%s) = %s C', $idx, $pos, $c));
    $self->add_perfdata(
      label    => $metric,
      value    => $c,
      warning  => $w,
      critical => $cr,
    );
  }

  if (! $self->check_messages()) {
    $self->add_ok('environmental hardware working fine');
  }
}

sub dump {
  my ($self) = @_;
  if ($self->{have_fsos_dc}) {
    foreach (@{$self->{fans}}, @{$self->{psus}}, @{$self->{temps}}) {
      $_->dump();
    }
    return;
  }
  my $items = $self->{no_sensors} ? $self->{entities} : $self->{sensors};
  foreach (@{$items || []}) {
    $_->dump();
  }
}


package CheckNwcHealth::FSOS::Component::EnvironmentalSubsystem::FanRotor;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;


package CheckNwcHealth::FSOS::Component::EnvironmentalSubsystem::PowerSupply;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;


package CheckNwcHealth::FSOS::Component::EnvironmentalSubsystem::TempSensor;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;


package CheckNwcHealth::FSOS::Component::EnvironmentalSubsystem::Entity;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub check {
  my ($self) = @_;
  if (defined $self->{entPhysicalClass} &&
      $self->{entPhysicalClass} =~ /^(fan|powerSupply|sensor)$/) {
    $self->add_info(sprintf 'entity %s (%s) found',
        $self->{entPhysicalName},
        $self->{entPhysicalClass});
  }
}


package CheckNwcHealth::FSOS::Component::EnvironmentalSubsystem::Sensor;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub check {
  my ($self) = @_;
  if ($self->{entPhySensorOperStatus} ne 'ok') {
    $self->add_info(sprintf '%s sensor %s has status %s',
        $self->{entPhySensorType},
        $self->{entPhySensorEntityName},
        $self->{entPhySensorOperStatus});
    if ($self->{entPhySensorOperStatus} eq 'nonoperational') {
      $self->add_critical();
    } else {
      $self->add_unknown();
    }
  } else {
    $self->add_info(sprintf "%s sensor %s reports %s%s",
        $self->{entPhySensorType},
        $self->{entPhySensorEntityName},
        $self->{entPhySensorValue},
        $self->{entPhySensorUnitsDisplay}
    );
  }
}
