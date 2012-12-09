use strict;
use warnings;
use JSON 'decode_json';
use Text::CSV;
use DateTime;
use Data::Dumper;

use Data::ICal;
use Data::ICal::Entry::Event;
use Data::ICal::Entry::Alarm::Email;
use Date::ICal;

my @dayOfWeeks = qw( Mon Tue Wed Thu Fri Sat Sun );
my $calscale = 'GREGORIAN';
my $timezone = 'Asia/Tokyo';
#my $offset = '-0900';

# load setting file
my $scheduleFile = $ARGV[0];
my $patternFile = $ARGV[1];
my $icalFile = $ARGV[2];
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
for my $pattern ( keys %$shiftPattern ){
	my ( $startHour, $startMin ) = $shiftPattern->{$pattern}->{shift}->[0] =~ /(\d{1,2}):(\d{1,2})/;
	my ( $endHour, $endMin ) = $shiftPattern->{$pattern}->{shift}->[1] =~ /(\d{1,2}):(\d{1,2})/;
	$startHour =~ s/0(\d)/$1/;
	$startMin  =~ s/0(\d)/$1/;
	$endHour   =~ s/0(\d)/$1/;
	$endMin    =~ s/0(\d)/$1/;
	$shiftPattern->{$pattern}->{startHour} = $startHour;
	$shiftPattern->{$pattern}->{startMin}  = $startMin;
	$shiftPattern->{$pattern}->{endHour}   = $endHour;
	$shiftPattern->{$pattern}->{endMin}    = $endMin;

	foreach my $alarm ( @{$shiftPattern->{$pattern}->{alarms}} ){
		push @{$shiftPattern->{$pattern}->{$alarm->{action}}->{alarm_durations}}, Date::ICal::Duration->new( $alarm->{durationUnit} => $alarm->{duration} );
	}
}
warn Dumper $shiftPattern;

my $calendar = Data::ICal->new();
$calendar->add_properties(
	'CALSCALE'      => $calscale,
	'X-WR-TIMEZONE' => $timezone,
);

foreach my $schedule ( @schedules ){
	next if ( !$schedule->{shift} );
	warn "\n\n$schedule->{date}\n";
	my $vevent = Data::ICal::Entry::Event->new();
	my ( $year, $month, $day ) = $schedule->{date} =~ /(\d{4})\/(\d{1,2})\/(\d{1,2})/;
	$month =~ s/0(\d)/$1/;
	$day   =~ s/0(\d)/$1/;
	my $dtstart = Date::ICal->new(
		year  => $year,
		month => $month,
		day   => $day,
		hour  => $shiftPattern->{$schedule->{shift}}->{startHour},
		min   => $shiftPattern->{$schedule->{shift}}->{startMin},
		sec => 0,
	#	offset => $offset,
	);
	warn $shiftPattern->{$schedule->{shift}}->{startHour};
	warn $shiftPattern->{$schedule->{shift}}->{startMin};
	my $dtend = Date::ICal->new(
		year  => $year,
		month => $month,
		day   => $day,
		hour  => $shiftPattern->{$schedule->{shift}}->{endHour},
		min   => $shiftPattern->{$schedule->{shift}}->{endMin},
		sec => 0,
	#	offset => $offset,
	);
	$dtend->add('day') if $dtstart > $dtend;
	my $dtstart_ical = $dtstart->ical;
	my $dtend_ical   = $dtend->ical;
	$dtstart_ical =~ s/^(\d{8})Z/$1T000000Z/;
	$dtend_ical   =~ s/^(\d{8})Z/$1T000000Z/;
	warn Dumper $dtstart_ical;
	warn Dumper $dtend_ical;
	
	$vevent->add_properties(
		summary => "Shift $schedule->{shift}",
		dtstart => $dtstart_ical,
		dtend => $dtend_ical,
	);


	my $valarm_email = Data::ICal::Entry::Alarm::Email->new();
	my @alarm_times_audio;
	my @alarm_times_display;
	my @alarm_times_email;
	my @alarm_times_procedure;

	foreach my $alarm ( @{$shiftPattern->{$schedule->{shift}}->{email}->{alarm_durations}} ){
		push @alarm_times_email, ($dtstart - $alarm)->ical;
	}
	$valarm_email->add_properties(
		trigger => @alarm_times_email,
	);

	$vevent->add_entry($valarm_email);
	warn Dumper $vevent;
	$calendar->add_entry($vevent);
}

print $calendar->as_string;


