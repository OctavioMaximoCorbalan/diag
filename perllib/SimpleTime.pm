package SimpleTime;

use POSIX;
use HTTP::Date;
use strict;

our (@ISA, @EXPORT, @EXPORT_OK);

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(
  str_2_time
  time_2_str
  time_2_iso
  time_2_gmtiso
);
@EXPORT_OK = qw(
  time_2_isoz
  day_of_month
  day_of_week
  day_of_year
  add_days
  add_months
  add_years
  add_weeks
  fs_day
  fs_month
  fs_year
  fs_week
  timezone
  time_local
  time_gm
);

use warnings(FATAL => 'all');
our $tz = timezone();
our @month = qw/1 2 3 4 5 6 7 8 9 10 11 12/;
our @days_of_month = qw/31 28 31 30 31 30 31 31 30 31 30 31/;
our $leap_feb_days = 29;

=head1 NAME

SimpleTime - Time processing Module.

=head3 Function List

=over 4

  str_2_time    -- Conver time string to timestamp
  time_2_str    -- Conver timestamp to time string
  time_2_iso    -- Conver time to "YYYY-MM-DD hh:mm:ss"

  time_2_isoz   -- Conver time to "YYYY-MM-DD hh:mm:ssZ" Universal Time
  day_of_month  -- which day it is in the month
  day_of_week   -- which day it is in the week
  day_of_year   -- whick day it is in the year
  add_days      -- add days to current timestamp
  add_months    -- add months to current timestamp
  add_years     -- add years to current timestamp
  add_weeks     -- add weeks to current timestamp
  fs_day        -- first second of day of this timestamp
  fs_month      -- first second of month of this timestamp
  fs_year       -- first second of year of this timestamp
  fs_week       -- first second of week of this timestamp
  timezone      -- return timezone
  time_local    -- get timestamp by local time
  time_gm       -- get timestamp by globle time

=back

=head4 Common Datetime formats

=over 4 

 "Wed, 09 Feb 1994 22:23:32 GMT"       -- HTTP format
 "Thu Feb  3 17:03:55 GMT 1994"        -- ctime(3) format
 "Thu Feb  3 00:00:00 1994",           -- ANSI C asctime() format
 "Tuesday, 08-Feb-94 14:15:29 GMT"     -- old rfc850 HTTP format
 "Tuesday, 08-Feb-1994 14:15:29 GMT"   -- broken rfc850 HTTP format

 "03/Feb/1994:17:03:55 -0700"   -- common logfile format
 "09 Feb 1994 22:23:32 GMT"     -- HTTP format (no weekday)
 "08-Feb-94 14:15:29 GMT"       -- rfc850 format (no weekday)
 "08-Feb-1994 14:15:29 GMT"     -- broken rfc850 format (no weekday)

 "1994-02-03 14:15:29 -0100"    -- ISO 8601 format
 "1994-02-03 14:15:29"          -- zone is optional
 "1994-02-03"                   -- only date
 "1994-02-03T14:15:29"          -- Use T as separator
 "19940203T141529Z"             -- ISO 8601 compact format
 "19940203"                     -- only date

 "08-Feb-94"         -- old rfc850 HTTP format    (no weekday, no time)
 "08-Feb-1994"       -- broken rfc850 HTTP format (no weekday, no time)
 "09 Feb 1994"       -- proposed new HTTP format  (no weekday, no time)
 "03/Feb/1994"       -- common logfile format     (no time, no offset)

 "Feb  3  1994"      -- Unix 'ls -l' format
 "Feb  3 17:03"      -- Unix 'ls -l' format

 "11-15-96  03:52PM" -- Windows 'dir' format

=back

=head4 strftime Date Format

=over 4

  %a - The abbreviated weekday name according to the current locale. 
  %A - The full weekday name according to the current locale. 
  %b - The abbreviated month name according to the current locale. 
  %B - The full month name according to the current locale. 
  %c - The preferred date and time representation for the current locale. 
  %C - The century number (year/100) as a 2-digit integer. (SU) 
  %d - The day of the month as a decimal number (range 01 to 31). 
  %D - Equivalent to %m/%d/%y. (Yecch -- for Americans only. Americans should note that in other countries %d/%m/%y is rather common. This means that in international context this format is ambiguous and should not be used.) (SU) 
  %e - Like %d, the day of the month as a decimal number, but a leading zero is replaced by a space. (SU) 
  %E - Modifier: use alternative format, see below. (SU) 
  %F - Equivalent to %Y-%m-%d (the ISO 8601 date format). (C99) 
  %G - The ISO 8601 year with century as a decimal number. The 4-digit year corresponding to the ISO week number (see %V). This has the same format and value as %y, except that if the ISO week number belongs to the previous or next year, that year is used instead. (TZ) 
  %g - Like %G, but without century, i.e., with a 2-digit year (00-99). (TZ) 
  %h - Equivalent to %b. (SU) 
  %H - The hour as a decimal number using a 24-hour clock (range 00 to 23). 
  %I - The hour as a decimal number using a 12-hour clock (range 01 to 12). 
  %j - The day of the year as a decimal number (range 001 to 366). 
  %k - The hour (24-hour clock) as a decimal number (range 0 to 23); single digits are preceded by a blank. (See also %H.) (TZ) 
  %l - The hour (12-hour clock) as a decimal number (range 1 to 12); single digits are preceded by a blank. (See also %I.) (TZ) 
  %m - The month as a decimal number (range 01 to 12). 
  %M - The minute as a decimal number (range 00 to 59). 
  %n - A newline character. (SU) 
  %O - Modifier: use alternative format, see below. (SU) 
  %p - Either 'AM' or 'PM' according to the given time value, or the corresponding strings for the current locale. Noon is treated as 'pm' and midnight as 'am'. 
  %P - Like %p but in lowercase: 'am' or 'pm' or a corresponding string for the current locale. (GNU) 
  %r - The time in a.m. or p.m. notation. In the POSIX locale this is equivalent to '%I:%M:%S %p'. (SU) 
  %R - The time in 24-hour notation (%H:%M). (SU) For a version including the seconds, see %T below. 
  %s - The number of seconds since the Epoch, i.e., since 1970-01-01 00:00:00 UTC. (TZ) 
  %S - The second as a decimal number (range 00 to 60). (The range is up to 60 to allow for occasional leap seconds.) 
  %t - A tab character. (SU) 
  %T - The time in 24-hour notation (%H:%M:%S). (SU) 
  %u - The day of the week as a decimal, range 1 to 7, Monday being 1. See also %w. (SU) 
  %U - The week number of the current year as a decimal number, range 00 to 53, starting with the first Sunday as the first day of week 01. See also %V and %W. 
  %V - The ISO 8601:1988 week number of the current year as a decimal number, range 01 to 53, where week 1 is the first week that has at least 4 days in the current year, and with Monday as the first day of the week. See also %U and %W. (SU) 
  %w - The day of the week as a decimal, range 0 to 6, Sunday being 0. See also %u. 
  %W - The week number of the current year as a decimal number, range 00 to 53, starting with the first Monday as the first day of week 01. 
  %x - The preferred date representation for the current locale without the time. 
  %X - The preferred time representation for the current locale without the date. 
  %y - The year as a decimal number without a century (range 00 to 99). 
  %Y - The year as a decimal number including the century. 
  %z - The time-zone as hour offset from GMT. Required to emit RFC 822-conformant dates (using "%a, %d %b %Y %H:%M:%S %z"). (GNU) 
  %Z - The time zone or name or abbreviation. 
  %+ - The date and time in date(1) format. (TZ) (Not supported in glibc2.) 
  %% - A literal '%' character.

=back

=head1 AUTHOR
  Julius Zhu
 
=cut

# str_2_time( $str [, $zone] )
#    converts a string to machine time. 
#    It returns undef if the format of $str is unrecognized
sub str_2_time($;$){
  my $str = shift;
  my $zone = shift;
  $zone = $tz if not defined $zone;
  return HTTP::Date::str2time($str, $zone);
}

# time_2_str( [$time] )
#    The time2str() function converts a machine time (seconds since epoch) to a string. 
#    Use the current time by default.
#    The string returned is in the format preferred for the HTTP protocol. 
#    This is a fixed length subset of the format defined by RFC 1123, represented in Universal Time (GMT). 
#    An example of a time stamp in this format is: Sun, 06 Nov 1994 08:49:37 GMT
sub time_2_str(;$$){
  my $time = shift;
  $time = time if not defined $time;
  $time = str_2_time($time) unless($time =~ /^\d+$/);
  my $format = shift;
  #unless($format){
  #  return HTTP::Date::time2str($time);
  #}else{
  #  return POSIX::strftime($format, localtime($time));
  #}
  return POSIX::strftime($format || "%a, %d %b %Y %H:%M:%S %z", localtime($time));
}

sub time_2_gmstr(;$$){
  my $time = shift;
  $time = time if not defined $time;
  $time = str_2_time($time) unless($time =~ /^\d+$/);
  my $format = shift;
  #unless($format){
  #  return HTTP::Date::time2str($time);
  #}else{
  #  return POSIX::strftime($format, localtime($time));
  #}
  return POSIX::strftime($format || "%a, %d %b %Y %H:%M:%S %z", gmtime($time));
}

# time_2_iso( [$time] )
#    Same as time_2_str(), but returns a "YYYY-MM-DD hh:mm:ss"-formatted string representing time in the local time zone.
sub time_2_iso(;$){
  my $t = shift;
  $t = time if not defined $t;
  $t = str_2_time($t) unless($t =~ /^\d+$/);
  return HTTP::Date::time2iso($t);
}

# time_2_isoz( [$time] )
#    Same as time_2_str(), but returns a "YYYY-MM-DD hh:mm:ssZ"-formatted string representing Universal Time.
sub time_2_isoz(;$){
  my $t = shift;
  $t = time if not defined $t;
  $t = str_2_time($t) unless($t =~ /^\d+$/);
  return HTTP::Date::time2isoz($t);
}

sub time_2_gmtiso(;$){
  return time_2_gmstr(shift, "%Y-%m-%d %H:%M:%S");
}

# day_of_month( [$time] )
sub day_of_month(;$){
  my $time = shift;
  $time = time if not defined $time;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  return $mday;
}

# day_of_week( [$time, $offset] )
sub day_of_week(;$$){
  my $time = shift;
  $time = time if not defined $time;
  my $offset = shift || 0;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  $wday = ($wday-$offset)%7;
  return $wday;
}

# day_of_year( [$time] )
sub day_of_year(;$){
  my $time = shift;
  $time = time if not defined $time;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  return $yday;
}

# add_days( [$time, $offset] )
#   default current time add 1 day
#   offset could be minus
sub add_days(;$$){
  my $time = shift;
  $time = time if not defined $time;
  my $offset = shift;
  $offset = 1 unless(defined $offset);
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  my @new_date = add_days_to_date($mday,$mon,$year, $offset);
  return Time::Local::timelocal($sec,$min,$hour, @new_date);
}

# add_months( [$time, $offset] )
#   default current time add 1 month
#   offset could be minus
sub add_months(;$$){
  my $time = shift;
  $time = time if not defined $time;
  my $offset = shift;
  $offset = 1 unless(defined $offset);
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  my $m = $mon+$offset;
  $mon = $m%12;
  if($m<0){
    $year += int($m/12)-1;
  }else{
    $year += int($m/12);
  }
  my @new_date = add_days_to_date(1,$mon,$year, $mday-1);
  return Time::Local::timelocal($sec,$min,$hour, @new_date);
}

# add_years( [$time, $offset] )
#   default current time add 1 year
#   offset could be minus
sub add_years(;$$){
  my $time = shift;
  $time = time if not defined $time;
  my $offset = shift;
  $offset = 1 unless(defined $offset);
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  $year += $offset;
  my @new_date = add_days_to_date(1,$mon,$year, $mday-1); # Feb 29
  return Time::Local::timelocal($sec,$min,$hour, @new_date);
}

# add_weeks( [$time, $offset] )
#   default current time add 1 week
#   offset could be minus
sub add_weeks(;$$){
  my $time = shift;
  $time = time if not defined $time;
  my $offset = shift;
  $offset = 1 unless(defined $offset);
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  my @new_date = add_days_to_date($mday,$mon,$year, $offset*7);
  return Time::Local::timelocal($sec,$min,$hour, @new_date);
}

# first second of day
# fs_day( [$time] )
#    default current time
sub fs_day(;$){
  my $time = shift;
  $time = time if not defined $time;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  return Time::Local::timelocal(0,0,0,$mday,$mon,$year);
}

# first second of month
# fs_month( [$time] )
#    default current time
sub fs_month(;$){
  my $time = shift;
  $time = time if not defined $time;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  return Time::Local::timelocal(0,0,0,1,$mon,$year);
}

# first second of year
# fs_year( [$time] )
#    default current time
sub fs_year(;$){
  my $time = shift;
  $time = time if not defined $time;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  return Time::Local::timelocal(0,0,0,1,0,$year);
}

# first second of week
# fs_week( [$time, $offset] )
#    default current time, offset=0 means week start from sunday, minus backward, positive forward
sub fs_week(;$$){
  my $time = shift;
  $time = time if not defined $time;
  my $offset = shift || 0;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  $sec=$min=$hour=0;
  $wday = ($wday-$offset)%7;
  my @new_date = add_days_to_date($mday,$mon,$year, -$wday);
  return Time::Local::timelocal($sec,$min,$hour, @new_date);
}

sub ld_day(;$){
  return fs_day(shift);
}
sub ld_month(;$){
  my $time = shift;
  $time = time if not defined $time;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  $sec=$min=$hour=0;
  $mday = days_of_month($mon, $year);
  return Time::Local::timelocal($sec,$min,$hour, $mday, $mon, $year);
}
sub ld_year(;$){
  my $time = shift;
  $time = time if not defined $time;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  $sec=$min=$hour=0;
  return Time::Local::timelocal($sec,$min,$hour, 31, $#month, $year);
}
sub ld_week(;$$){
  my $time = shift;
  $time = time if not defined $time;
  my $offset = shift || 0;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  $sec=$min=$hour=0;
  $wday = ($wday-$offset)%7;
  my @new_date = add_days_to_date($mday,$mon,$year, 6-$wday);
  return Time::Local::timelocal($sec,$min,$hour, @new_date);
}
sub ls_day(;$){
  my $time = shift;
  $time = time if not defined $time;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  $sec=59; $min=59; $hour=23;
  return Time::Local::timelocal($sec,$min,$hour,$mday,$mon,$year);
}
sub ls_month(;$){
  my $time = shift;
  $time = time if not defined $time;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  $sec=59; $min=59; $hour=23;
  $mday = days_of_month($mon, $year);
  return Time::Local::timelocal($sec,$min,$hour, $mday, $mon, $year);
}
sub ls_year(;$){
  my $time = shift;
  $time = time if not defined $time;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  $sec=59; $min=59; $hour=23;
  return Time::Local::timelocal($sec,$min,$hour, 31, $#month, $year);
}
sub ls_week(;$$){
  my $time = shift;
  $time = time if not defined $time;
  my $offset = shift || 0;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  $sec=59; $min=59; $hour=23;
  $wday = ($wday-$offset)%7;
  my @new_date = add_days_to_date($mday,$mon,$year, 6-$wday);
  return Time::Local::timelocal($sec,$min,$hour, @new_date);
}
sub is_leap_year{
  my $year = shift;
  return 1 if($year%100>0 and $year%4 == 0 or $year%400==0);
  return undef;
}
sub days_of_month{
  my $mon = shift;
  my $year = shift;
  return $leap_feb_days if($mon == 2 and is_leap_year($year));
  return $days_of_month[$mon];
}
# get timezone of current machine
sub timezone{
  my $t = time;
  my @gt = gmtime($t);
  my $tt = Time::Local::timelocal($gt[0],$gt[1],$gt[2],$gt[3],$gt[4],$gt[5]);
  my $tz = int(($t-$tt)/3600);
  return $tz;
}

# add days to an exist date
sub add_days_to_date{
  my($d, $m, $y, $days) = @_;
  my $t = Time::Local::timegm(0,0,0,$d,$m,$y);
  $t += $days * 86400;
  my @gt = gmtime($t);
  return ($gt[3], $gt[4], $gt[5]);
}

# get time from local time params
sub time_local{
  my ($sec,$min,$hour,$mday,$mon,$year) = @_;
  if($sec<0){$min += int($sec/60)-1;}else{$min += int($sec/60);}
  $sec = $sec % 60;
  if($min<0){$hour += int($min/60)-1;}else{$hour += int($min/60);}
  $min = $min % 60;
  if($hour<0){$mday += int($hour/24)-1;}else{$mday += int($hour/24);}
  $hour = $hour % 24;
  
  if($mon<0){$year += int($mon/12)-1;}else{$year += int($mon/12);}
  $mon = $mon % 12;
  
  my @new_date = add_days_to_date(1,$mon,$year, $mday-1);
  return Time::Local::timelocal($sec,$min,$hour, @new_date);
}

# get time from globle time params
sub time_gm{
  my ($sec,$min,$hour,$mday,$mon,$year) = @_;
  if($sec<0){$min += int($sec/60)-1;}else{$min += int($sec/60);}
  $sec = $sec % 60;
  if($min<0){$hour += int($min/60)-1;}else{$hour += int($min/60);}
  $min = $min % 60;
  if($hour<0){$mday += int($hour/24)-1;}else{$mday += int($hour/24);}
  $hour = $hour % 24;
  
  if($mon<0){$year += int($mon/12)-1;}else{$year += int($mon/12);}
  $mon = $mon % 12;
  
  my $t = Time::Local::timegm($sec,$min,$hour,1,$mon,$year);
  $t += ($mday-1) * 86400;
  return $t;
}

1;
__END__
