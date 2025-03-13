package MIDI::RtController::Filter::Drums;

# ABSTRACT: RtController drum filters

use v5.36;

our $VERSION = '0.0101';

use Moo;
use strictures 2;
use List::SomeUtils qw(first_index);
use List::Util qw(shuffle uniq);
use Music::Scales qw(get_scale_MIDI get_scale_notes);
use Music::Chord::Note ();
use Music::Note ();
use Music::ToRoman ();
use Music::VoiceGen ();
use Types::Standard qw(ArrayRef Num);
use namespace::clean;

=head1 SYNOPSIS

  use MIDI::RtController ();
  use MIDI::RtController::Filter::Drums ();

  my $rtc = MIDI::RtController->new; # * input/output required

  my $rtf = MIDI::RtController::Filter::Drums->new(rtc => $rtc);

  $rtc->add_filter('foo', note_on => $rtf->can('foo'));

  $rtc->run;

=head1 DESCRIPTION

C<MIDI::RtController::Filter::Drums> is the collection of
L<MIDI::RtController> filters for the drums.

=cut

=head1 ATTRIBUTES

=head2 rtc

  $rtc = $rtf->rtc;

The required L<MIDI::RtController> instance provided in the
constructor.

=cut

has rtc => (
    is  => 'ro',
    isa => sub { die 'Invalid rtc' unless ref($_[0]) eq 'MIDI::RtController' },
    required => 1,
);

=head2 feedback

  $feedback = $rtf->feedback;
  $rtf->feedback($number);

The feedback (0-127).

Default: C<1>

=cut

has feedback => (
    is  => 'rw',
    isa => Num,
    default => sub { 1 },
);

=head2 bpm

  $bpm = $rtf->bpm;
  $rtf->bpm($number);

The beats per minute.

Default: C<120>

=cut

has bpm => (
    is  => 'rw',
    isa => Num,
    default => sub { 120 },
);

=head1 METHODS

All filter methods must accept the object, a delta-time, and a MIDI
event ARRAY reference, like:

  sub drums ($self, $dt, $event) {
    my ($event_type, $chan, $note, $value) = $event->@*;
    ...
    return $boolean;
  }

A filter also must return a boolean value. This tells
L<MIDI::RtController> to continue processing other known filters or
not.

=head2 drum_tone

Play the drums.

=cut

sub _drum_parts ($self, $note) {
    my $part;
    if ($note == 99) {
        $part = sub {
            my (%args) = @_;
            $args{drummer}->metronome4;
        };
    }
    else {
        $part = sub {
            my (%args) = @_;
            $args{drummer}->note($args{drummer}->sixtyfourth, $note);
        };
    }
    return $part;
}
sub drums ($self, $dt, $event) {
    my ($ev, $chan, $note, $vel) = $event->@*;
    return 1 unless $ev eq 'note_on';
    my $part = $self->_drum_parts($note);
    my $d = MIDI::Drummer::Tiny->new(
        bpm  => $self->bpm,
        bars => $self->feedback,
    );
    MIDI::RtMidi::ScorePlayer->new(
      device   => $self->rtc->_midi_out,
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

L<Moo>

L<List::SomeUtils>

L<Music::Scales>

L<Music::Chord::Note>

L<Music::Note>

L<Music::ToRoman>

L<Music::VoiceGen>

=cut
