package MyCli;

use strict;
use warnings(FATAL=>'all');

use Getopt::Long;
use SimpleTime;
use Data::Dumper;

our (@ISA, @EXPORT, @EXPORT_OK);
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(%args $debug printd printdl printl get_result_ascii $start_time);
@EXPORT_OK = qw();

use subs qw/printd printdl printl check_args get_result_ascii get_term_bkg_rst/;

our %args;
our $debug;
our $start_time = time;
our @tsl_opt; # options that not supported by wrapper will pass to tserverlite
our @cmd_var_opt; # optiosn start with "ud-", user defined options

sub init{
  printdl "=== Start at ".time_2_iso($start_time)." === [$$]";
  push @main::arg_format, "help|h|?", "debug";
  pre_process_arg_format();
  GetOptions(\%args, @main::arg_format) or die("Error in command line arguments\n");
  set_cmd_var();
  set_tsl_opt();
  check_args();
}

sub pre_process_arg_format{
  my %defined_arg;
  for(@main::arg_format){
    if(/^([^=:]+)/){
      my $opt = $1;
      my $not_flag = 0;
      if($opt =~ /(.+)!$/){
        $not_flag = 1;
        $opt = $1;
      }
      for(split '\|', $opt){
        $defined_arg{$_}++;
        $defined_arg{"no$_"}++ if $not_flag;
      }
    }
  }
  my @opt_format; # stack to store format strings
  my @tmp_format; # tmp format array
  for my $arg(@ARGV){
    if ($arg =~ /^\-{1,2}([^=:]+)([=:]?)/){
      my ($opt, $has_value) = ($1, $2);
      next if $opt eq "cf"; # special process for cf;
      
      if(@opt_format){
        push @tmp_format, join "", @opt_format;
        @opt_format = ();
      }
      if(not exists $defined_arg{$opt}){
        push @opt_format, $opt;
        push @opt_format, "=s" if $has_value;
        if($opt =~ /^ud\-/){
          push @cmd_var_opt, $opt;
        }else{
          push @tsl_opt, $opt;
        }
      }
    }else{
      push @opt_format, "=s" if @opt_format == 1;
    }
  }
  push @tmp_format, join "", @opt_format if @opt_format;
  push @tmp_format, "cf=s@";
  push @main::arg_format, @tmp_format;
}

sub set_cmd_var{
  for my $opt(@cmd_var_opt){
    if($opt =~ /^ud\-(.+)/){
      $main::cmd_var{$1} = $args{$opt};
    }
  }
}

sub set_tsl_opt{
  my @opts;
  my %flag_format;
  for(@main::arg_format){
    $flag_format{$_}++ unless /[=:]/;
  }
  if($args{cf}){
    foreach my $cf(@{$args{cf}}){
      push @opts, "-cf=$cf";
    }
  }
  for my $opt(@tsl_opt){
    if($args{$opt} eq "1" and $flag_format{$opt}){
      # test if it is flag
      push  @opts, "-$opt";
    }elsif($args{$opt} =~ /\s/){
      push @opts, "-$opt=\"$args{$opt}\"";
    }else{
      push @opts, "-$opt=$args{$opt}";
    }
  }
  push @opts, "-pr" if -e ".arg_pr";
  for(glob("dev*.mod")){
    if(/dev(\d+)\.mod/){
      my $d = $1;
      push @opts, "-d=$d";
    }
  }
  $main::tsl_param = join " ", @opts;
}

sub check_args{
  Help(0) if $args{help};
  if($args{debug}){
    $debug = 1;
  }
  printdl "Args:";
  printdl Dumper (\%args);
  printdl;
  
  if(defined &{"main::CheckArgs"}){
    &main::CheckArgs();
  }
}

sub Help{
  my $code = shift;
  $code = 1 unless defined $code;
  Usage();
  exit $code;
}

sub Usage{
  if(defined &{"main::Usage"}){
    &main::Usage();
  }else{
    print <<EOF;
Usage: perl $0
 -debug   enable debug output
 -help   show this message
EOF
  }
}

#### helper ####
sub printd{
  if($^O =~ /linux-goingtodelte/i){
    print "\033[4m",@_,"\033[0m" if $debug;
  }else{
    print @_ if $debug;
  }
}
sub printdl{
  printd(@_);
  printd "\n";
}
sub printl{
  print @_;
  print "\n";
}

sub get_term_bkg_rst{
  my $type = shift;
  my $is_linux = 0;
  my $is_osx = 0;
  $is_linux = 1 if $^O =~ /linux/i;
  $is_osx = 1 if $^O =~ /darwin/i;

  my %cfg = (
PASS => {bkg=>"\033[1;37;42m", rst=>"\033[0m"},
FAIL => {bkg=>"\033[1;37;41m", rst=>"\033[0m"},
SKIP => {bkg=>"\033[1;37;44m", rst=>"\033[0m"},
);
  my ($bkg, $rst) = ("", "");
  if($is_linux || $is_osx){
    $bkg = $cfg{$type}{bkg};
    $rst = $cfg{$type}{rst};
  }
  return ($bkg, $rst);
}

sub get_result_ascii{
  my $word = shift || "PASS";
	
  my %ascii = (
PASS =>
"    _/_/_/      _/_/      _/_/_/    _/_/_/   
   _/    _/  _/    _/  _/        _/          
  _/_/_/    _/_/_/_/    _/_/      _/_/       
 _/        _/    _/        _/        _/      
_/        _/    _/  _/_/_/    _/_/_/         ",
FAIL =>
"    _/_/_/_/    _/_/    _/_/_/  _/     
   _/        _/    _/    _/    _/      
  _/_/_/    _/_/_/_/    _/    _/       
 _/        _/    _/    _/    _/        
_/        _/    _/  _/_/_/  _/_/_/_/   ",
SKIP =>
"    _/_/_/_/  _/  _/   _/_/_/  _/_/_/    
   _/        _/ _/      _/    _/    _/   
  _/_/_/_/  _/_/       _/    _/_/_/      
       _/  _/  _/     _/    _/           
_/_/_/_/  _/    _/ _/_/_/  _/           "
);
  my ($bkg, $rst) = ("", "");
    
  if($word =~ /PASS/i){
    ($bkg, $rst) = get_term_bkg_rst("PASS");
  }elsif($word =~ /FAIL/i){
    ($bkg, $rst) = get_term_bkg_rst("FAIL");
  }elsif($word =~ /SKIP/i){
    ($bkg, $rst) = get_term_bkg_rst("SKIP");
  }

  my $ascii = $ascii{$word} || $word;
  my $str = join "\n", map {"$bkg$_$rst"} split /\n/, $ascii;
  return $str;
}

sub END{
  printdl "=== End at ".time_2_iso." === [$$]\n";
}

1;
