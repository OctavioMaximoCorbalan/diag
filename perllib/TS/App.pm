package TS::App;

use strict;
use TS::AppConf;

our $AUTOLOAD;

# get app location
#my $app = "$TS::AppConf::cmd_pre$TS::AppConf::tool_app";
my %attr  = (app=>undef, param=>'');

sub new{
  my $class=shift;
  my %params = @_;
  my $self = {};
  bless $self, $class;
  for my $k(keys %params){
    if( exists $attr{$k}){
      $self->{$k} = $params{$k};
    }else{
      die "Invalid attr: $k was set to ".(defined $params{$k} ? $params{$k} : '' );
    }
  }
  die "App wasn't specified" unless $self->{app};
  if($self->{app} =~ /^\$(.*)/){
    my $app = $1;
    $self->{app} = TS::AppConf::get_app($app);
  }  
  $self->{param} = '' if not defined $self->{param};
  return $self;
}

sub is_tool{
  my $self = shift;
  if(not exists $self->{is_tool}){
    $self->{is_tool} = $self->{app} =~ /\b(agt|agt_internal)\b/ ? 1 : 0;
  }
  return $self->{is_tool};
}

sub is_tool_mode{
  my $self = shift;
  if(not exists $self->{is_tool_mode}){
    if($self->is_tool and $self->{param} =~ /^\-ppmode=(\S*)(.*)$/){
      $self->{is_tool_mode} = 1;
      $self->{tool_mode} = $1;
      $self->{tool_mode_param} = $2;
      $self->{tool_mode_param} = "" if not defined $self->{tool_mode_param};
      $self->{tool_mode_param} .= " -zfb" if $main::args{zfb};
    }else{
      $self->{is_tool_mode} = 0;
      $self->{tool_mode} = '';
    }
  }
  return $self->{is_tool_mode};  
}

sub tool_mode{
  my $self = shift;
  if(not exists $self->{tool_mode}){
    $self->is_tool_mode;
  }
  return $self->{tool_mode};
}

sub ignore_rc{
  my $self = shift;
  if($self->is_tool and $main::args{notoolrc}){
    return 1;
  }else{
    return 0;
  }
}

sub get_cmd{
  my $self = shift;
  return $self->{cmd} if $self->{cmd};
  my @d = &main::get_device_list();

  my $asic = $d[0]{name};
  if($main::global{d} and $main::global{d} =~ /^[\d,]+$/){
    my $did = (split /,/, $main::global{d})[0];
    $asic = $d[$did-1]{name};
  }

  my $cmd = "$self->{app} $self->{param}";
  if($self->is_tool){ # tool setting
    my @cmd;
    if($self->is_tool_mode){
      my $mode = $self->tool_mode;
      my $state_cmds = $self->set_state_cmd($mode, $asic);
      push @cmd, @$state_cmds;
    }else{
      push @cmd, "$self->{app} $self->{param}";
    }

    my @dev_opt;
    if($main::global{d} and $main::global{d} =~ /^[\d,]+$/){
      for my $dindex(split /,/, $main::global{d}){
        if($dindex =~ /^\d+$/){
          die "Invalide device(-d=$dindex) specified.\n" unless @d >= $dindex;
          push @dev_opt, " -i=". $d[$dindex-1]{pci};
        }
      }
    }elsif($main::global{d} and $main::global{d} eq "gpu.*"){
      for(&main::get_device_list()){
        push @dev_opt, " -i=$_->{pci}" if $_ and $_->{pci};
      }
    }else{
      push @dev_opt, "";
    }

    my @all_cmd;
    for my $c(@cmd){
      for my $d(@dev_opt){
        push @all_cmd, "$c$d";
      }
    }
    $cmd = join "\n", @all_cmd;    
  }

  # replace interplate variables
  $cmd =~ s/\\/\\\\/g;
  $cmd =~ s/"/\\"/g;
  $cmd =~ s/\$(\w+)/\$main\::cmd_var{$1}/mg;
  #$cmd =~ s/\[(.*?)\]/\$main\::cmd_var{$1}/g;
  eval('$cmd="'.$cmd.'"');  
  $self->{cmd} = $cmd;
  return $cmd;
}

sub run{
  my $self = shift;
  my $rc = 0;
  my $cmds = $self->get_cmd;
  my @output;
  if($cmds){
    for(split "\n", $cmds){
      open PIPE, "-|", $_ or die "$!";
      while(<PIPE>){
        print $_;
        push @output, $_;
      }
      close PIPE;
      my $rc2 = $?;
      $rc = $rc2 if $rc2 != 0;
    }
  }else{
    print "No command to execute, probably cannot find device\n";
  }
  return wantarray ? ($rc, \@output) : $rc;
}

sub set_state_cmd{
  my $self = shift;
  my $pmode = shift;
  my $asic = shift;
  my @cmd;
  my ($mode, $sclk_dpm_state, $mclk_dpm_state, $eng_inc, $mem_inc) = ($pmode || "perf", "max", "max", 0, 0);
  my $vddc_inc = 0;
  if($asic and $asic =~ /navi|mi100|mi200/i) {
        if ($mode eq "boot"){
          push @cmd, "$self->{app} -ppmode=boot $self->{tool_mode_param}";
        }  
  }elsif($asic and $asic =~ /carrizo|stoney/i){
	  push @cmd, "$self->{app} -ppmode=boot $self->{tool_mode_param}";
  }else{
	  push @cmd, "$self->{app} -ppdpmrestore=sclk";
	  push @cmd, "$self->{app} -ppdpmrestore=soc";
	  push @cmd, "$self->{app} -ppdpmrestore=mclk";
	  push @cmd, "$self->{app} -fancontrol=2" if $main::args{maxfan};
	  push @cmd, "$self->{app} -ppmode=boot $self->{tool_mode_param}";
  }
  
  my $ppreg = -e "ppreg.dat" ? "-ppreadreg=ppreg.dat" : "";

  if($mode ne "boot"){
    if($main::env->{setstate}){
      if($main::config->{defstate}){
        $mode = $pmode || $main::config->{defstate}{mode};
        $sclk_dpm_state = $main::config->{defstate}{sclk_dpm_state};
        $mclk_dpm_state = $main::config->{defstate}{mclk_dpm_state};
      }
      if($mode eq 'perf' and $main::config->{suitemargin}){
          $eng_inc = $main::config->{suitemargin}{eng_inc};
          $mem_inc = $main::config->{suitemargin}{mem_inc};
          $vddc_inc = $main::config->{suitemargin}{vddc_inc};

        if($asic and $asic =~ /iceland|vega12/i){
          if ($eng_inc =~ /(\-?[\w\.]+)\%$/) {
             my $percent = $1;
             if (not ($vddc_inc eq '0x100' or $vddc_inc eq '0x0' or $vddc_inc eq '0')) {
                 push @cmd, "$self->{app} $self->{tool_mode_param} $ppreg -ppvidoffset=$vddc_inc";
             }
	     push @cmd, "$self->{app} $ppreg -ppmode=$mode $self->{tool_mode_param} -ppengpct=$eng_inc -ppmempct=$mem_inc";
          }
          else {
             if (not ($vddc_inc eq '0x100' or $vddc_inc eq '0x0' or $vddc_inc eq '0')) {
                 push @cmd, "$self->{app} $self->{tool_mode_param} $ppreg -ppvidoffset=$vddc_inc";
             }
             push @cmd, "$self->{app} $ppreg -ppmode=$mode $self->{tool_mode_param} -ppmempct=$mem_inc";
	     push @cmd, "$self->{app} $self->{tool_mode_param} $ppreg -ppsclkoffset=$eng_inc";
          }
        }else{
          if ($mem_inc =~ /(\-?[\w\.]+)\%$/) {
             my $percent = $1;
	     push @cmd, "$self->{app} $ppreg -ppmode=$mode $self->{tool_mode_param} -ppmempct=$percent";
          }
          else {
              push @cmd, "$self->{app} $ppreg -ppmode=$mode $self->{tool_mode_param} -ppmempct=$mem_inc";
          }

          if ($eng_inc =~ /(\-?[\w\.]+)\%$/) {
             my $percent = $1;
             if (not ($vddc_inc eq '0x100' or $vddc_inc eq '0x0' or $vddc_inc eq '0')) {
                 push @cmd, "$self->{app} $self->{tool_mode_param} $ppreg -ppvidoffset=$vddc_inc";
             }
	     push @cmd, "$self->{app} $self->{tool_mode_param} $ppreg -ppsclkoffsetpct=$percent";
          }
          else {
             if (not ($vddc_inc eq '0x100' or $vddc_inc eq '0x0' or $vddc_inc eq '0')) {
                 push @cmd, "$self->{app} $self->{tool_mode_param} $ppreg -ppvidoffset=$vddc_inc";
             }
	     push @cmd, "$self->{app} $self->{tool_mode_param} $ppreg -ppsclkoffset=$eng_inc";
          }
        }
      }else{
        if($asic and $asic =~ /carrizo|stoney|navi|mi100|mi200/i){
          push @cmd, "$self->{app} -ppmode=$mode $ppreg $self->{tool_mode_param}";
        }elsif($asic and $asic =~ /greenland|vega/i){   
          push @cmd, "$self->{app} -ppdpmrestore=sclk";
          push @cmd, "$self->{app} -ppdpmrestore=soc";
          push @cmd, "$self->{app} -ppdpmrestore=mclk";
          push @cmd, "$self->{app} -ppmode=$mode $ppreg $self->{tool_mode_param}";
        }else{
          push @cmd, "$self->{app} -ppdpmrestore=sclk";
          push @cmd, "$self->{app} -ppdpmrestore=mclk";
          push @cmd, "$self->{app} -ppmode=$mode $ppreg $self->{tool_mode_param}";
        }   
      }
      if(not$main::env->{ignoreforcemax}){
       #push @cmd, "$self->{app} -ppdpmforce=sclk,$sclk_dpm_state";
       #push @cmd, "$self->{app} -ppdpmforce=mclk,$mclk_dpm_state";
        push @cmd, "$self->{app} -fancontrol=1" if $main::args{maxfan};
      }
    }elsif($asic and $asic =~ /navi1.*/i){
        push @cmd, "$self->{app} -ppdpmrestore=sclk";
	push @cmd, "$self->{app} -ppdpmrestore=soc";
	push @cmd, "$self->{app} -ppdpmrestore=mclk";
        push @cmd, "$self->{app} -ppmode=$mode $ppreg $self->{tool_mode_param}";
    }elsif($asic and $asic =~ /mi100|mi200/i){
        push @cmd, "$self->{app} -ppdpmrestore=sclk";
        push @cmd, "$self->{app} -ppmode=$mode $ppreg $self->{tool_mode_param}";
    }else{
      push @cmd, "$self->{app} -ppmode=$mode $ppreg $self->{tool_mode_param}";
    }
  }
  return \@cmd;
}

sub AUTOLOAD{
  my $self = shift;
  my $sub = $AUTOLOAD;
  $sub =~ s/.*:://;
  if(exists $attr{$sub}){
    $self->{$sub} = $_[0] if @_ > 0;
    return $self->{$sub};
  }else{
    die "Cannot find method $AUTOLOAD\n";
  }
}

1;
__END__
