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
#use Data::UUID;

my @dayOfWeeks = qw( Mon Tue Wed Thu Fri Sat Sun );
#my $offset = '-0900';

# load setting file
my $scheduleFile = $ARGV[0];
my $patternFile = $ARGV[1];
my $icalFile = $ARGV[2];
#warn $scheduleFile;
#warn $patternFile;

my @schedules;
my $csv = Text::CSV->new({
	auto_diag => 1,
	binary => 1,
});
open(my $fh, '<', $scheduleFile);
while (my $column = $csv->getline($fh)){
	push(@schedules, { date => $column->[0], shift => $column->[1] });
}
#warn Dumper @schedules;

my $json;
{
	local $/; #Enable 'slurp' mode
	open my $fh, "<", $patternFile;
	$json = <$fh>;
	close $fh;
}
my $shiftPattern = decode_json($json);
#warn Dumper $shiftPattern;
#warn Dumper $shiftPattern->{shift};
for my $pattern ( keys %{$shiftPattern->{shift}} ){
	#warn Dumper $pattern;
	my ( $startHour, $startMin ) = $shiftPattern->{shift}->{$pattern}->[0] =~ /(\d{1,2}):(\d{1,2})/;
	my ( $endHour, $endMin )     = $shiftPattern->{shift}->{$pattern}->[1] =~ /(\d{1,2}):(\d{1,2})/;
	$startHour =~ s/0(\d)/$1/;
	$startMin  =~ s/0(\d)/$1/;
	$endHour   =~ s/0(\d)/$1/;
	$endMin    =~ s/0(\d)/$1/;
	$shiftPattern->{shift}->{$pattern}->[2] = $startHour;
	$shiftPattern->{shift}->{$pattern}->[3] = $startMin;
	$shiftPattern->{shift}->{$pattern}->[4] = $endHour;
	$shiftPattern->{shift}->{$pattern}->[5] = $endMin;

#	foreach my $alarm ( @{$shiftPattern->{shift}->{$pattern}->{alarms}} ){
#		push @{$shiftPattern->{shift}->{$pattern}->{$alarm->{action}}->{alarm_durations}}, Date::ICal::Duration->new( $alarm->{durationUnit} => $alarm->{duration} );
#	}
}
#warn Dumper $shiftPattern;

my $calendar;
if ( -f "$icalFile" ){
	$calendar = Data::ICal->new( filename => $icalFile );
} else {
	$calendar = Data::ICal->new();
	$calendar->add_properties(
		'X-WR-CALNAME'  => $shiftPattern->{calinfo}->{calname},
		'CALSCALE'      => $shiftPattern->{calinfo}->{calscale},
		'X-WR-TIMEZONE' => $shiftPattern->{calinfo}->{timezone},
	);
}

foreach my $schedule ( @schedules ){
	next if ( !$schedule->{shift} );
#	#warn "\n\n$schedule->{date}\n";
	my $vevent = Data::ICal::Entry::Event->new();
	my ( $year, $month, $day ) = $schedule->{date} =~ /(\d{4})\/(\d{1,2})\/(\d{1,2})/;
	$month =~ s/0(\d)/$1/;
	$day   =~ s/0(\d)/$1/;
	my $dtstart = Date::ICal->new(
		year  => $year,
		month => $month,
		day   => $day,
		hour  => $shiftPattern->{shift}->{$schedule->{shift}}->[2],
		min   => $shiftPattern->{shift}->{$schedule->{shift}}->[3],
		sec => 0,
	#	offset => $offset,
	);
	#warn $shiftPattern->{shift}->{$schedule->{shift}}->[2];
	#warn $shiftPattern->{shift}->{$schedule->{shift}}->[3];
	my $dtend = Date::ICal->new(
		year  => $year,
		month => $month,
		day   => $day,
		hour  => $shiftPattern->{shift}->{$schedule->{shift}}->[4],
		min   => $shiftPattern->{shift}->{$schedule->{shift}}->[5],
		sec => 0,
	#	offset => $offset,
	);
	$dtend->add('day') if $dtstart > $dtend;
	my $dtstart_ical = $dtstart->ical;
	my $dtend_ical   = $dtend->ical;
	$dtstart_ical =~ s/^(\d{8})Z/$1T000000Z/;
	$dtend_ical   =~ s/^(\d{8})Z/$1T000000Z/;
	#warn Dumper $dtstart_ical;
	#warn Dumper $dtend_ical;
	
	$vevent->add_properties(
		SUMMARY => "$schedule->{shift}",
		DTSTART => $dtstart_ical,
		DTEND   => $dtend_ical,
#		UID     => Data::UUID->new->create_str,
	);

#	my $valarm_email = Data::ICal::Entry::Alarm::Email->new();
#	my @alarm_times_audio;
#	my @alarm_times_display;
#	my @alarm_times_email;
#	my @alarm_times_procedure;
#
#	foreach my $alarm ( @{$shiftPattern->{$schedule->{shift}}->{email}->{alarm_durations}} ){
#		push @alarm_times_email, ($dtstart - $alarm)->ical;
#	}
#	$valarm_email->add_properties(
#		trigger => @alarm_times_email,
#	);
#
#	$vevent->add_entry($valarm_email);
#	#warn Dumper $vevent;
	$calendar->add_entry($vevent);
}

# output ical file
open (OUT, ">$icalFile") or die "$!";
print OUT $calendar->as_string;
close (OUT);
