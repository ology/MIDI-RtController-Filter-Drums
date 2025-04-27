package MIDI::RtController::Filter::Drums;

# ABSTRACT: Generic RtController drum filter

use v5.36;

our $VERSION = '0.0400';

use strictures 2;
use List::SomeUtils qw(first_index);
use MIDI::Drummer::Tiny ();
use MIDI::RtMidi::ScorePlayer ();
use Moo;
use Types::Common::Numeric qw(PositiveInt);
use Types::Standard qw(CodeRef HashRef);
use namespace::clean;

extends 'MIDI::RtController::Filter';

=head1 SYNOPSIS

  use curry;
  use Future::IO::Impl::IOAsync; # because ScorePlayer is async
  use MIDI::RtController ();
  use MIDI::RtController::Filter::Drums ();

  my $controller = MIDI::RtController->new(
    input   => 'keyboard',
    output  => 'usb',
    verbose => 1,
  );

  my $filter = MIDI::RtController::Filter::Drums->new(rtc => $controller);

  $filter->bars(8);
  $filter->phrase(\&my_phrase);
  $filter->common({ foo => 42 });

  # for triggering with a note_on message:
  $filter->trigger(99); # note 99 (D#7/Eb7)

  # or for triggering with a control_change:
  # $filter->trigger(25); # CC 25
  # $filter->value(127);

  $controller->add_filter('drums', note_on => $filter->curry::drums);

  $controller->run;

  sub my_phrase {
    my (%args) = @_;
    if ($args{foo} == 42) {
      $args{drummer}->metronome4;
    }
    else {
      $args{drummer}->metronome5;
    }
  }

=head1 DESCRIPTION

C<MIDI::RtController::Filter::Drums> is a generic
L<MIDI::RtController> drum filter.

=cut

=head1 ATTRIBUTES

=head2 bars

  $bars = $filter->bars;
  $filter->bars($number);

The number of measures to set for the drummer bars.

Default: C<1>

=cut

has bars => (
    is  => 'rw',
    isa => PositiveInt,
    default => sub { 1 },
);

=head2 bpm

  $bpm = $filter->bpm;
  $filter->bpm($number);

The beats per minute.

Default: C<120>

=cut

has bpm => (
    is  => 'rw',
    isa => PositiveInt,
    default => sub { 120 },
);

=head2 phrase

  $filter->phrase(\&your_phrase);
  $part = $filter->phrase();

The subroutine given to this attribute takes a collection of named
parameters to do its thing. Primarily, this is a
L<MIDI::Drummer::Tiny> instance named "drummer."

=cut

has phrase => (
    is      => 'rw',
    isa     => CodeRef,
    builder => 1,
);

sub _build_phrase {
    return sub {
        my (%args) = @_;
        $args{drummer}->metronome4;
    };
}

=head2 common

  $common = $filter->common;
  $filter->common($common);

These are custom arguments given to the phrase.

A L<MIDI::Tiny::Drummer> instance, named "drummer" is added to this
list when executing the B<phrase>.

Default: C<{}> (no arguments)

Default: C<120>

=cut

has common => (
    is  => 'rw',
    isa => HashRef,
    default => sub { {} },
);

=head1 METHODS

All filter methods must accept the object, a MIDI device name, a
delta-time, and a MIDI event ARRAY reference, like:

  sub drums ($self, $device, $delta, $event) {
    my ($event_type, $chan, $note, $value) = $event->@*;
    ...
    return $boolean;
  }

A filter also must return a boolean value. This tells
L<MIDI::RtController> to continue processing other known filters or
not.

=head2 drums

Play the drums.

If B<trigger> or B<value> is set, the filter checks those against the
MIDI event C<note> or C<value>, respectively, to see if the filter
should be applied.

=cut

sub _drum_part ($self, $note) {
    my $part;
    if (defined $self->trigger && $note == $self->trigger) {
        $part = $self->phrase;
    }
    else {
        $part = sub {
            my (%args) = @_;
            $args{drummer}->note($args{drummer}->sixtyfourth, $note);
        };
    }
    return $part;
}
sub drums ($self, $device, $dt, $event) {
    my ($ev, $chan, $note, $val) = $event->@*;

    return 0 unless $ev eq 'note_on'
        || ($ev eq 'control_change' && defined $self->value && $val == $self->value);

    my $part = $self->_drum_part($note);

    my $d = MIDI::Drummer::Tiny->new(
        bpm  => $self->bpm,
        bars => $self->bars,
    );

    my $common = $self->common;
    $common = { %$common, drummer => $d };

    MIDI::RtMidi::ScorePlayer->new(
      device   => $self->rtc->midi_out,
      score    => $d->score,
      common   => $common,
      parts    => [ $part ],
      sleep    => 0,
      infinite => 0,
    )->play_async->retain;

    return 1;
}

1;
__END__

=head1 SEE ALSO

The F<eg/*.pl> program(s) in this distribution

L<MIDI::RtController::Filter>

L<List::SomeUtils>

L<MIDI::Drummer::Tiny>

L<MIDI::RtController>

L<MIDI::RtMidi::ScorePlayer>

L<Moo>

L<Types::Common::Numeric>

L<Types::Standard>

=cut
