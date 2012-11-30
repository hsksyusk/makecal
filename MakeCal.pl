#!/Users/hsksyusk/perl5/perlbrew/perls/perl-5.14.2/bin/perl
use strict;
use warnings;
use JSON 'decode_json';
use Text::CSV;
use DateTime;
use Data::Dumper;

my @dayOfWeeks = qw( Mon Tue Wed Thu Fri Sat Sun );

# load setting file
my $scheduleFile = $ARGV[0];
my $patternFile = $ARGV[1];
warn $scheduleFile;
warn $patternFile;

my @schedules;
my $csv = Text::CSV->new({
	auto_diag => 1,
	binary => 1,
});
open(my $fh, '<', $scheduleFile);
while (my $column = $csv->getline($fh)){
	push(@schedules, { date => $column->[0], shift => $column->[1] });
}
warn Dumper @schedules;

my $json;
{
	local $/; #Enable 'slurp' mode
	open my $fh, "<", $patternFile;
	$json = <$fh>;
	close $fh;
}
my $shiftPattern = decode_json($json);
warn Dumper $shiftPattern;

my $calendar = Data::ICal->new();

foreach my $schedule ( @schedules ){
	if ( !$schedule->{shift} ) last;
	my $vevent = Data::ICal::Entry::Event->new();
	my ( $year, $month, $day ) = $schedule->{date} =~ /(\d{4})\/(\d{1,2})\/(\d{1,2})/;
	my ( $startHour, $startMin ) = $shiftPattern{$schedule->{shift}}->{shift}->[0] =~ /(\d{1,2}):(\d{1,2})/
	my $event_ical = Data::ICal->new(
		year  => $year,
		month => $month,
		day   => $day,
		hour  => $startHour,
		min => $startMin,
		sec => 0
	);
	$vevent->add_properties(
		summary => "Summary of Event",
		dtsart => $event_ical->ical,
	);
	my $valarm = Data::ICal::Entry::Alarm::Email->new();
	my @alarm_times;
	if ( $shiftPattern{$schedule->{shift}}->alarms
	my $alarm_time = $event_ical - 

