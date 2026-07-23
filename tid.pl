#!/usr/bin/perl

# This is an example report generator. 
# It demonstrates how to parse the log files and create a custom report.
# This one generates a version of legacy file 'testid.log'
# This can be invoked by the tserver wrapper as a post-processing step after test completion.
#
# To run that way in general, use:
#     ./tserver -log -tid -report="my_path/my_report" -cf=tserver.cf -tf=my.stf
#  ...and replacing 'my_report' with the name of this script:
#     ./tserver -log -tid -report="./tid.pl" -cf=tserver.cf -tf=my.stf
#
#
#  2015/10/27 MF  Bugfix for YAML::Tiny last-doc-only problems.
#

use strict;
use File::Basename;
use lib dirname(__FILE__)."/perllib";
use YAML::Tiny;
use subs qw/printl/;

main();

sub main{
  my $report = "mytestid.log";
  open REP, ">>", $report or die "cannot open $report $!";
  select REP;
  convert_yaml_to_testid();
  select STDOUT;
  close REP;
}

sub printl{
  print @_, "\n";
}

sub convert_yaml_to_testid{
    my $yml;
    eval {
        $yml = YAML::Tiny->read("log.yml");
    };
    if ($@)
    {
        print "$YAML::Tiny::errstr\n";
        print "try to parse as many as possible\n";

        #copy malfunctioning file as backup file

        open (my $yaml, "+<", "log.yml") or die "Can not open log.yml";
        open (my $yamlbk, "+>", "log.bk.yml") or die $!;
        while(<$yaml>) 
        {
            print $yamlbk $_;
        }

        close $yamlbk;
        close $yaml;

        open (my $yaml, ">", "log.yml") or die "Can not open log.yml";
        open (my $yamlbk, "+<", "log.bk.yml") or die $!;

        while(<$yamlbk>) 
        {
            print $yaml $_ unless (/\0\0/ or /^\0/);
        }

        close $yamlbk;
        close $yaml;

        $yml = YAML::Tiny->read("log.yml");
    };

  unless($yml and @$yml and %{$yml->[-1]}){
    print "log.yml is empty\n";
    return;
  }

  foreach my $doc(@$yml) {
    my $result = {};
    my %tests;
    $result->{results} = $doc->{results};
    $result->{command} = $doc->{command};
    $result->{tests} = [];
    foreach my $t(@{$doc->{tests}}){
      if($t->{start}){
        $tests{$t->{start}} = {id=>$t->{id}, device_id=>$t->{device_id}};
        push @{$result->{tests}}, {test=>$tests{$t->{start}}}; # save records
      }elsif($t->{end}){
        if($tests{$t->{end}}){ # key exists
          $tests{$t->{end}}{elapsed} = $t->{elapsed};
          $tests{$t->{end}}{result} = $t->{result};
          if($t->{errors}){
              if (ref $t->{errors} eq "ARRAY"){
                  $tests{$t->{end}}{errors} = $t->{errors} unless $t->{errors}[0] eq "No Errors Reported";
              } else {
                  $tests{$t->{end}}{errors} = $t->{errors} if $t->{errors} and $t->{errors} !~ /No Errors Reported/;
              }
          }
          delete $tests{$t->{end}};
        }
      }elsif($t->{test}){
        push @{$result->{tests}}, {test=>$t->{test}};
      }
      foreach(values %tests){
        $_->{result} = "Hang";
      }
    }
    print_doc($result);
  }
}

sub print_doc{
  my $result = shift;
  return unless $result and %$result and $result->{command};
  printl $result->{command}, ($result->{results}? "($result->{results}{date} $result->{results}{time} GMT)" : "");
  for my $t(@{$result->{tests}}){
    my $elap = $t->{test}{elapsed};
    if(defined $elap){
      $elap =~ s/[^\d\.]//g;
      $elap = $elap/1000;
    }else{
      $elap = "*";
    }
    printl "$t->{test}{id}    [$t->{test}{device_id}] $t->{test}{result}    $elap sec.";
    printl "ERROR: $t->{test}{errors}" if $t->{test}{errors};
  }
  if($result->{results}){
    my $elap = $result->{results}{elapsed};
    $elap = $elap/1000;
    printl "Total Pass:\t$result->{results}{pass}";
    printl "Total Fail:\t$result->{results}{fail}";
    if ($result->{results}{abort}) {
      printl "Total Abort:\t$result->{results}{abort}";
    } else {
      printl "Total Abort:\t0";
    }
    printl "Total Skip:\t$result->{results}{skip}";
    printl "Elapsed Time:\t$elap"."s";
  }
}
