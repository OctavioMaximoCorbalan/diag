#!/usr/bin/perl
###checklist.pl usage:###
###1. create func in tswrapper.pl: backup_tidchecklist, to backup testid.log to checklist in BP flow. ### 
###2. running command: "perl checklist.pl" to parser all tool settings in flow.###
###the change is only implemented on 15_07 branch now, may need to check standoard uotput in tswrapper.pl for trunk and modify some output file.###

my $file = "checklist";
#return unless -e "testid.log" or die "no such file\n";
#rename "testid.log", $file;
open(FILE, '<'. $file) or die "Cannot open '$file' to write $!";
while (my $line = <FILE>){
	chomp $line;
	if (my $count= ($line =~ /([\s]*Mode[\s]\=[\s]\d{1,})[\s]\:[\s](\w{4,})[\s]\:/)){
		$count_1 += $count;
		print "PP_mode check ", $count_1,": ",$1,", ppmode is: ", $2,"\n";
	}elsif(my $count = ($line =~/([\s]*DPM[\s]level[\s]forced)[\s]to[\s](\d{1,})/)){
		$count_2 += $count;
		print "Force DPM check ",$count_2,": Force DPM level is ", $2, "\n";
	}elsif(my $count = ($line =~ /([\s]*Engine[\s]Clock)[\s]+\:[\s]+(\d{3,})\.(\d{2,})[\s]MHz$/)){
		$count_3 += $count;
		print "SCLK check ", $count_3, ":", $2, ".", "$3","MHz","\n";
	}elsif(my $count = ($line =~ /([\s]*Memory[\s]Clock)[\s]+\:[\s]+(\d{3,})\.(\d{2,})[\s]MHz$/)){
		$count_4 += $count;
		print "MCLK check ", $count_4, ":", $2, ".", "$3","MHz","\n";
	}elsif(my $count =($line =~ /([\s]*SCLK[\s]offset)[\s]+\([\s](\d{1,}\.\d{2,}\%)\)([\s]\w+[\s]\w+)\.$/)){
		$count_5 += $count;
		print "Margin check ", $count_5, ":", $1, "(margin)", $2, $3,"\n";
	}

}

close(FILE);



