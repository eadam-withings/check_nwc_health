package CheckNwcHealth::Alcatel;
our @ISA = qw(CheckNwcHealth::Device);
use strict;

sub init {
  my ($self) = @_;
  if ($self->{productname} =~ /AOS.*OAW/i) {
    bless $self, 'CheckNwcHealth::Alcatel::OmniAccess';
    $self->debug('using CheckNwcHealth::Alcatel::OmniAccess');
  }
  if (ref($self) ne "CheckNwcHealth::Alcatel") {
    $self->init();
  } else {
    # no OmniAccess submodel matched: this is a plain OmniSwitch (or any
    # mode we do not implement here). Hand over to the generic fallback so
    # device-independent modes like uptime/interfaces still work.
    $self->no_such_mode();
  }
}

