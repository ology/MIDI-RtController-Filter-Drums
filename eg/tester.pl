#!/usr/bin/env perl

use curry;
use Future::IO::Impl::IOAsync;
use MIDI::RtController ();
use MIDI::RtController::Filter::Drums ();

my $input_name  = shift || 'tempopad'; # midi controller device
my $output_name = shift || 'fluid';    # fluidsynth

my $rtc = MIDI::RtController->new(
    input  => $input_name,
    output => $output_name,
);

my $rtfd = MIDI::RtController::Filter::Drums->new(rtc => $rtc);

$rtc->add_filter('drums', [qw(note_on note_off)], $rtfd->curry::drums);

$rtc->run;
