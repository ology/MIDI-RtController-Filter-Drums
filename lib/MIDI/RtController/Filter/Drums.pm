package MIDI::RtController::Filter::Drums;

# ABSTRACT: RtController drum filters

use v5.36;

our $VERSION = '0.0301';

use strictures 2;
use List::SomeUtils qw(first_index);
use MIDI::Drummer::Tiny ();
use MIDI::RtMidi::ScorePlayer ();
use Moo;
use Types::Standard qw(ArrayRef CodeRef Num Maybe);
use namespace::clean;

=head1 SYNOPSIS

  use curry;
  use Future::IO::Impl::IOAsync;
  use MIDI::RtController ();
  use MIDI::RtController::Filter::Drums ();

  my $controller = MIDI::RtController->new(
    input   => 'keyboard',
    output  => 'usb',
    verbose => 1,
  );

  my $filter = MIDI::RtController::Filter::Drums->new(rtc => $controller);

  $filter->phrase(\&my_phrase);
  $filter->trigger(99); # trigger the phrase with note 99
  $filter->bars(8);

  $controller->add_filter('drums', note_on => $filter->curry::drums);

  $controller->run;

  sub my_phrase {
    my (%args) = @_;
    $args{drummer}->metronome7;
  }

=head1 DESCRIPTION

C<MIDI::RtController::Filter::Drums> is the L<MIDI::RtController>
filter for the drums. It is meant to be an example of how to make a
drum filter and uses the 4/4 metronome for this.

=cut

=head1 ATTRIBUTES

=head2 rtc

  $controller = $filter->rtc;

The required L<MIDI::RtController> instance provided in the
constructor.

=cut

has rtc => (
    is  => 'ro',
    isa => sub { die 'Invalid controller' unless ref($_[0]) eq 'MIDI::RtController' },
    required => 1,
);

=head2 value

  $value = $filter->value;
  $filter->value($number);

Return or set the MIDI event value. This is a generic setting that can
be used by filters to set or retrieve state. This often a whole number
between C<0> and C<127>, but can take any number.

Default: C<undef>

=cut

has value => (
    is      => 'rw',
    isa     => Maybe[Num],
    default => undef,
);

=head2 trigger

  $trigger = $filter->trigger;
  $filter->trigger($number);

Return or set the trigger. This is a generic setting that
can be used by filters to set or retrieve state. This often a whole
number between C<0> and C<127>, but can take any number.

Default: C<undef>

=cut

has trigger => (
    is      => 'rw',
    isa     => Maybe[Num],
    default => undef,
);

=head2 bars

  $bars = $filter->bars;
  $filter->bars($number);

The number of measures to set for the drummer bars.

Default: C<1>

=cut

has bars => (
    is  => 'rw',
    isa => Num,
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
    isa => Num,
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

sub _drum_parts ($self, $note) {
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
    my $part = $self->_drum_parts($note);
    my $d = MIDI::Drummer::Tiny->new(
        bpm  => $self->bpm,
        bars => $self->bars,
    );
    MIDI::RtMidi::ScorePlayer->new(
      device   => $self->rtc->midi_out,
      score    => $d->score,
      common   => { drummer => $d },
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

L<MIDI::RtController::Filter::Tonal> - Related module

L<MIDI::RtController::Filter::Math> - Related module

L<MIDI::RtController::Filter::CC> - Related module

L<List::SomeUtils>

L<MIDI::Drummer::Tiny>

L<MIDI::RtController>

L<MIDI::RtMidi::ScorePlayer>

L<Moo>

L<Types::Standard>

=cut
