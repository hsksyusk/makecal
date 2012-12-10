use strict;
use warnings;
use JSON 'decode_json';
use DateTime;
use Data::Dumper;

my @dayOfWeeks = qw( Mon Tue Wed Thu Fri Sat Sun );

# load setting file
my $filename = shift;

my $json;
{
	local $/; #Enable 'slurp' mode
	open my $fh, "<", $filename;
	$json = <$fh>;
	close $fh;
}
my $basicSchedule = decode_json($json);
# warn Dumper $basicSchedule;

# make first date & last date
my $date = DateTime->new(
	time_zone => 'Asia/Tokyo',
	year => $basicSchedule->{year},
	month => $basicSchedule->{month},
	day => 1
);
my $lastDate = DateTime->last_day_of_month(
	time_zone => 'Asia/Tokyo',
	year => $basicSchedule->{year},
	month => $basicSchedule->{month}
);

# make iCalendar loop
for ( 1 ; $date <= $lastDate; $date = $date->add( days => 1) ){
	print "$basicSchedule->{year}/", sprintf("%02d",$basicSchedule->{month}), "/", sprintf("%02d",$date->day), "($dayOfWeeks[$date->wday-1]),";
	# check schedule
	if ( $dayOfWeeks[$date->wday-1] ~~ \@{$basicSchedule->{dayOfWeeks}} ){
		print "$basicSchedule->{shift}\n";
	} else {
		print "\n";
	}
}

