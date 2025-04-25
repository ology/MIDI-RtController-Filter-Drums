#!/usr/bin/env perl

use curry;
use Future::IO::Impl::IOAsync;
use MIDI::RtController ();
use MIDI::RtController::Filter::Drums ();

my $input_name  = shift || 'pad';   # midi controller device
my $output_name = shift || 'fluid'; # fluidsynth

my $rtc = MIDI::RtController->new(
    input   => $input_name,
    output  => $output_name,
    verbose => 1,
);

my $rtfd = MIDI::RtController::Filter::Drums->new(rtc => $rtc);

$rtfd->phrase(\&my_phrase);

$rtfd->bars(8);

$rtc->add_filter('drums', note_on => $rtfd->curry::drums);

$rtc->run;

sub my_phrase {
    my (%args) = @_;
    $args{drummer}->metronome3;
}
