package TS::AppConf;
# Author: Julius Zhu

use strict;

# This module detect tserver and tool location and name, export
#   $os : os name, win or linux
#   $is_win 
#   $is_linux
#   $tserver_app : the tserver application name , either tserver or tserverlite
#   $tool_app : the tool application name, either agt or agt_internal
#   $cmd_pre : the prefix to run app in cli, no prefix in win, "./" in linux

our $os = get_os();
our $is_win = ($os eq 'win');
our $is_linux = ($os eq 'linux');
our $is_osx = ($os eq 'osx');
our $cpu_type = get_platform();
our $is_intel = ($cpu_type eq "intel");
our $is_amd = ($cpu_type eq "amd");

my %app_conf = (
  win => {
    tserver=>["tserverlite.exe"], 
    tool=>["agt_internal", "agt.exe"],
    cmd_pre=>"",
    app_post=>".exe",
  },
  linux => {
    tserver=>["tserverlite"], 
    tool=>["agt_internal", "agt"],
    cmd_pre=>"./",
    app_post=>""
  },
  osx => {
    tserver=>["tserverlite"],
    tool=>["agt_internal", "agt"],
    cmd_pre=>"./",
    app_post=>""
  },
);

our $tserver_app = '';
for(@{$app_conf{$os}{tserver}}){
  $tserver_app = $_ and last if -e $_;
}
$tserver_app = $app_conf{$os}{tserver}[0] unless $tserver_app; # set default 

our $tool_app = '';
for(@{$app_conf{$os}{tool}}){
  $tool_app = $_ and last if -e $_;
}
$tool_app = $app_conf{$os}{tool}[0] unless $tool_app; # set default 

our $cmd_pre = $app_conf{$os}{cmd_pre};
our $app_post = $app_conf{$os}{app_post};

sub get_app{
  my $app = shift;
  if(defined $app_conf{$os}{$app}){
    for(@{$app_conf{$os}{$app}}){
      return $cmd_pre.$_ if -e $_;
    }
    return $cmd_pre.$app_conf{$os}{$app}[0]; # default to return first one
  }elsif($app !~ /\\|\//){
    return $cmd_pre.$app.$app_post;
  }else{
    return $app.$app_post;
  }
}

sub get_os{
  # unix like
  my $unix = "aix bsdos dgux dynixptx freebsd haiku linux hpux irix next openbsd dec_osf svr4 sco_sv unicos unicosmk solaris sunos";
  my $dos = "dos os2 ? MSWin32 cygwin";
  my $osx = "darwin";
  
  if($dos =~ /\b$^O\b/i){
    return "win";
  }elsif($unix =~ /\b$^O\b/i){
    return "linux";
  }elsif($osx =~ /\b$^O\b/i){
    return "osx";
  }else{
    die "Cannot detect your os type";
  }
}

sub get_platform{
  my $p = "unknow";
  if($os eq "linux"){
    if(not system("cat /proc/cpuinfo  | grep Intel > /dev/null")){
      $p = "intel";
    }elsif(not system("cat /proc/cpuinfo | grep AMD > /dev/null")){
      $p = "amd";
    }
  }elsif($os eq "win"){
    my $cpu = $ENV{PROCESSOR_IDENTIFIER} || '';
    if($cpu =~ /Intel/i){
      $p = "intel";
    }elsif($cpu =~ /AMD/i){
      $p = "amd";
    }
  }elsif($os eq "osx"){
    my $cpu = `sysctl machdep.cpu.brand_string`;
    if($cpu =~ /Intel/i){
      $p = "intel";
    }elsif($cpu =~ /AMD/i){
      $p = "amd";
    }
  }
  return $p;  
}

1;
