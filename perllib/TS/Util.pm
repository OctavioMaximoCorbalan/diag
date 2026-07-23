package TS::Util;

use strict;
use TS::Universe;
use TS::Param;
use TS::Block;
use TS::Case;
use TS::Func;
use TS::App;
use Data::Dumper;
use Carp;
use TS::AppConf;
use Cwd qw/abs_path/;
use File::Basename;
our (@ISA, @EXPORT, @EXPORT_OK);
our $config = TS::Universe::Config();
our $env = TS::Universe::Env();
our $tmp_test_params = [];
our $tmp_func_params = [];

use Exporter;

@ISA = qw/Exporter/;
@EXPORT = qw/
  register_param_option register_param_default 
  create_block create_block_from_tf create_func_from_sf create_cf 
  get_action_list_by_lines
  add_ip add_block add_tool add_restart add_test add_prog add_tf add_sub add_seqfile
  add_test_param clear_test_param add_func_param clear_func_param  
  second_2_read is_array_same
  set_env_opt save_env_opt restore_env_opt set_config_const set_global_opt
  read_file_last_line write_to_file write_to_file_add
  save_cfgdata read_cfgdata
  read_input read_input_text set_output restore_output
  support_tclist_option get_tclist get_tclist_case get_tclist_count search_expand_case
  split_option
  getrc
/;

sub register_param_option{
  my %param = @_;
  my ($package, $filename, $line) = caller;
  while(my ($p, $o) = each %param){
    my @opt = split ',', (join ',', @$o);
    foreach my $opt(@opt){
      $config->{params}{$p}{options}{$opt} = undef;
      if(defined &{"$package\::$opt"}){
        $config->{params}{$p}{options}{$opt} = \&{"$package\::$opt"};
      }else{
        die "No routine bind to this option $opt";
      }
    }
    TS::Universe::add_param(new TS::Param(name=>$p, type=>"string", opts=>\@opt));
  }
}

sub register_param_default{
  my %param = @_;
  while(my ($p, $o) = each %param){
    $config->{params}{$p}{default} = $o;
  }
}

sub create_block{
  my %blocks = @_;
  while(my($block, $tests) = each %blocks){
    my $block_obj = new TS::Block(name=>$block);
    my $params = [];
    push @$params, $_ foreach @$tmp_test_params;
    my $cf = [];
    my $case = [];
    my $restart_flag = 0;
  
    for my $line(split /\n/, $tests){
      chomp $line;
      $line =~ s/(^\s+|\s+$|\s*#.*$)//g; # remove comments
      next if $line eq '';
      if($line =~ /param:\s*(.*)$/){ # param line
        my $p = $1;
        for my $item(split /\s+/, $p){
          if($item =~ /^\-cf=(.*)$/ and $item !~ /\.cf$/){ # special cf
            push @$cf, $1;
          }else{
            push @$params, $item;
          }
        }
      }elsif($line =~ /restart/){ # restart line
        $restart_flag = 1;
      }else{ # case line
        my $c = $line;
        my $cf = [];
        my $case_params = [];
        my $restart = $restart_flag;
        $restart_flag = 0;
        # does case has special params
        if($line =~ /(.*?)\s+(.*)/){  # case has special param
          $c = $1;
          my $p = $2;
          my @p = split /\s+/, $p;
          for my $item(@p){
            if($item =~ /^\-cf=(.*)$/ and $item !~ /\.cf$/){ # special cf
              push @$cf, $1;
            }else{
              push @$case_params, $item;
            }
          }
        }
        my $os = '';
        if($c =~ /\[(.*?)\](.*)/){ # case has os specification
          $c = $2;
          $os = $1;
        }
        push @$case, new TS::Case(name=>$c, cf=>$cf, param=>$case_params, restart=>$restart, os=>$os);
      }
    }
    $block_obj->param($params);
    $block_obj->cf($cf);
    $block_obj->case($case);
    $config->{blocks}{$block} = $block_obj;
  }
}

sub create_block_from_tf{
  my $block = shift;
  my $bconf = shift;
  my $tests = shift;
  
  my $block_obj = new TS::Block(name=>$block);
  my $params = [];
  push @$params, $_ foreach @$tmp_test_params;
  my $cf = [];
  my $case = [];
  my $restart_flag = 0;
  
  while(my($k, $v) = each %$bconf){ # process conf 
    if($k eq 'CF'){
      if($v !~ /\.cf$/){ #if not end with cf, it's a predefined cf, should to to @$cf
        push @$cf, $v;
      }else{ # if end with cf, it's a commond line cf, should go to @$params.
        push @$params, "-cf=$v";
      }
    }elsif($k eq 'PAR' or $k eq 'PARA'){
      for my $item(split /\s+/, $v){ # splite params
        if($item =~ /^\-cf=(.*)$/ and $item !~ /\.cf$/){ # special cf
          push @$cf, $1;
        }else{
          push @$params, $item;
        }
      }
    }elsif($k eq 'MASK'){
      $block_obj->tf_ex(1);
    }elsif($k eq 'NOZFB'){
      $block_obj->nozfb(1);
    }elsif($k eq 'MASTER'){
      $block_obj->master(1);
    }
  }
  
  for my $line(@$tests){ # RESTART CMD
    next if $line eq '';
    if($line =~ /^#RESTART/){
      $restart_flag = 1;
    }elsif($line =~ /^#CMD\s*=\s*(.*)/){
      my $cmd = strip($1);
      my ($prog, $param) = $cmd =~ /(\S+)\s*(.*)/;
      push @$case, new TS::App(app=>$prog, param=>$param);
    }elsif($line =~ /^([^\s#]+?)\s*(#\s*(.*))?$/){ # parse options
      my($c, $option) = ($1, $3);
      $c = strip($c);
      my $cf = [];
      my $case_params = [];
      
      my $ncase = new TS::Case(name=>$c, restart=>$restart_flag);
      $restart_flag = 0; # reset restart_flag

      if($option){
        my $opt = split_option($option);
        for my $o(@$opt){
          if($o->{name} =~ /PARA?/){
            for my $item(split /\s+/, $o->{value}){
              if($item =~ /^\-cf=(.*)$/ and $item !~ /\.cf$/){ # special cf
                push @$cf, $1;
              }else{
                push @$case_params, $item;
              }
            }
          }elsif($o->{name}  eq 'OS'){
            $ncase->os($o->{value});
          }elsif($o->{name} eq 'NOZFB'){
            $ncase->nozfb(1);
          }elsif($o->{name} eq 'SKIPRETRY'){
            $ncase->retry($o->{value});
            $ncase->retry_type("SKIP");
          }elsif($o->{name} eq 'FAILRETRY'){
            $ncase->retry($o->{value});
            $ncase->retry_type("FAIL");
          }elsif($o->{name} eq "MASTER"){
            $ncase->master(1);
          }
        }
      }

      # should not add case to queue if os not matched
      $ncase->param($case_params);
      $ncase->cf($cf);
      push @$case, $ncase if match_os($ncase->os());
    }else{
      next;
    }
  }
  $block_obj->param($params);
  $block_obj->cf($cf);
  $block_obj->case($case);
  $config->{blocks}{$block} = $block_obj;
  return $block_obj;
}

sub get_action_list_by_lines{
   my $tests = shift;
   my @actions;
   my @params;
   my $restart_flag = 0;
   for my $line(@$tests){ # RESTART CMD
    chomp $line;
    $line =~ s/(^\s+|\s+$)//g;
    next if $line eq '';
    if($line =~ /^#RESTART/){ # restart
      $restart_flag = 1;
    }elsif($line =~ /^#CMD=(.*)/){ # cmd line
      my $cmd = $1;
      my ($prog, $param) = $cmd =~ /(\S+)\s*(.*)/;
      push @actions, new TS::App(app=>$prog, param=>$param);
    }elsif($line =~ /^#\s*(PARA?\s*=\s*.*)$/){ # param line
      my $param = $1;
      my $opt = split_option($param);
      foreach my $o(@$opt){
        if($o->{name} =~ /PARA?/){
          foreach my $p(split /\s+/, $o->{value}){
            push @params, $p;
          }
        }
      }
    }elsif($line =~ /^(\S+?)\s*(#\s*(.*))?$/){ # other case or options
      my($c, $option) = ($1, $3);
      my $cf = [];
      my $case_params = [];
      my $restart = $restart_flag;
      $restart_flag = 0;
      my $os = '';
      
      if($option){
        my $opt = split_option($option);
        for my $o(@$opt){
          if($o->{name} =~ /PARA?/){
            for my $item(split /\s+/, $o->{value}){
              if($item =~ /^\-cf=(.*)$/ and $item !~ /\.cf$/){ # special cf
                push @$cf, $1;
              }else{
                push @$case_params, $item;
              }
            }
          }elsif($o->{name}  eq 'OS'){
            $os = $o->{value};
          }
        } 
      }
      push @actions, new TS::Case(name=>$c, cf=>$cf, param=>$case_params, restart=>$restart, os=>$os) if match_os($os);
    }else{
      next;
    }
  }
  return \@actions, \@params;
}

sub create_func_from_sf{
  my $func = shift;
  my $stack = shift;
  my $param = shift;
  
  my $func_obj = new TS::Func(name=>$func, list=>$stack, param=>$param);
  $config->{funcs}{$func} = $func_obj;
}

sub create_cf{
  my %cfs = @_;
  while(my($cf, $opts) = each %cfs){
    my @t = split /\n/, $opts;
    my @list;
    for(@t){
      chomp;
      s/(^\s+|\s+$|\s*#.*$)//g;
      push @list, $_ if $_;
    }
    $config->{cfs}{$cf} = \@list;
  }
}

sub add_sub{
  my $sub = shift;
  push @{$env->{action_queue}}, $sub;
}

sub add_block{
  my $block = shift;
  $block = lc($block);
  my $filter = $main::args{filter};
  my $params = [];
  # process block level params
  if($block =~ /^(\S+)\s+(.+)$/){
    $block = $1;
    my $param = $2;
    # has more params
    for(split /\s+/, $param){
      next unless $_;
      push @$params, $_;
    }
  }
  push @$params, $_ foreach @$tmp_func_params; # write in func level params
  if(defined $config->{blocks}{$block}){
    my $block = $config->{blocks}{$block}->clone();
    for my $par(@$params){
      $block->add_param($par);
    }
    # deal with restart flag;
    if($env->{run}{restart}){
      $block->restart(1);
      remove_restart();
    }
    
    push @{$env->{action_queue}}, $block;   
    filter_test($filter, $block) if $filter;
  }else{
    die "Block $block doesn't exist\n";
  }
}

sub add_ip{
  
}

sub add_prog{
  my $app = shift;
  my ($prog, $param) = $app =~ /(\S+)\s*(.*)/;  
  push @{$env->{action_queue}}, new TS::App(app=>$prog, param=>$param);
}

sub add_test{
  my $test = shift;
  my $params = [];
  if($test =~ /^(\S+)\s+(.+)$/){
    $test = $1;
    my $param = $2;
    # has more params
    for(split /\s+/, $param){
      next unless $_;
      push @$params, $_;
    }
  }
  push @$params, $_ foreach @$tmp_func_params; # write in func level params
  
  # deal with restart flag;
  my $restart = 0;
  if($env->{run}{restart}){
    $restart = 1;
    remove_restart();
  }
  push @{$env->{action_queue}}, new TS::Case(name=>$test, param=>$params, restart=>$restart);
}

sub add_tool{
  my $tool_param = shift;
  add_prog("\$tool $tool_param");
  #push @{$env->{action_queue}}, new TS::App(app=>"\$tool", param=>$tool_param);
}

sub add_restart{
  $env->{run}{restart} = 1;
}

sub add_tf{
  my $tf = shift;
  my $filter = $main::args{filter};
  # process tf level params
  my $params = [];
  if($tf =~ /^(\S+)\s+(.+)$/){
    $tf = $1;
    my $param = $2;
    # has more params
    for(split /\s+/, $param){
      next unless $_;
      push @$params, $_;
    }
  }
  push @$params, $_ foreach @$tmp_func_params; # write in func level params
  if(defined $config->{test_files}{$tf}){
    my $tf_obj = $config->{test_files}{$tf}->clone();
    for my $par(@$params){
      $tf_obj->add_param($par);
    }
    push @{$env->{action_queue}}, $tf_obj;   
    filter_test($filter, $tf_obj) if $filter;
  }else{
    warn "Tf $tf doesn't exist\n";
  }
}
#--------------------------------------------------------------------------------
#   Name          : filter_test
#   Parameters    : filter          the option of filter 
#                   obj             a hash map to store context in STF or BLK
#   Return Values : no              
#   Desc          : Filter one test to run from an STF file or BLK
#-----------------------------------------------------------------------------
sub filter_test {
  my ($filter, $obj) = @_;
  $filter =~ s/\s+//g;
  my @filter_parm; 
  @filter_parm = split /\,/,lc($filter);
  my $f_blk; my $f_test;
  my $filter_par = [];
  foreach my $k (@filter_parm)
  { 
    if ($k =~ /blk/i) {
      my @key = split /\:/, $k;
      $f_blk = @key[1];
    } 
    if ($k =~ /test/i) {
      my @key = split /\:/, $k;
      $f_test = @key[1];
    }
  }
  push @$filter_par, {blk=>$f_blk, test=>$f_test};
  my $type = ref $obj;
  my @new_blk = [];
  my @new_case = [];
  if ($type eq 'TS::TestFile') 
  {
    if (@$filter_par[0]->{blk} eq "" and @$filter_par[0]->{test} ne "") {
      my $case_info = search_expand_case(@$filter_par[0]->{test}, "" , $obj->{name});
      if ($$case_info[0]) {
        foreach my $a2 (@{$obj->actions}) {
          if ((ref $a2 eq 'TS::Case' and $a2->{name} eq @$case_info[0]->{case}) or (ref $a2 ne 'TS::Case')) {
            if (ref $a2 eq 'TS::Case') {
              $a2->{name} = @$filter_par[0]->{test};
            }
            push @new_case, $a2;
          }
        }
        delete $obj->{actions};
        $obj->{actions} = \@new_case;
      } else {
        die "cannot find test @$filter_par[0]->{test} in stf file\n";
      }
    } elsif ( @$filter_par[0]->{blk} ne "" and @$filter_par[0]->{test} ne "") {
      my ($blk_found, $test_found);
      if (grep { $_->{name} eq @$filter_par[0]->{blk} } @{$obj->actions}) 
      {
        $blk_found = 1;
      }
      if ($blk_found == 1) {
        my $case_info = search_expand_case(@$filter_par[0]->{test}, @$filter_par[0]->{blk}, $obj->{name});
        if ($$case_info[0] ) {
          foreach my $a (@{$obj->actions}) {
            if ((ref $a eq 'TS::Block' and $a->{name} eq @$filter_par[0]->{blk}) or (ref $a ne 'TS::Block')) {
              if (ref $a eq 'TS::Block') {
                foreach my $a2 (@{$a->case}) {
                  if ((ref $a2 eq 'TS::Case' and $a2->{name} eq @$case_info[0]->{case}) or (ref $a2 ne 'TS::Case')) {
                    if (ref $a2 eq 'TS::Case') {
                      $a2->{name} = @$filter_par[0]->{test};
                      $test_found = 1;
                    }
                    push @new_case, $a2;
                  }
                }
                delete $a->{case};
                $a->{case} = \@new_case;
              }
              push @new_blk, $a;
            }
          }
          delete $obj->{actions};
          $obj->{actions} = \@new_blk;
        } else {
          die "cannnot find the test @$filter_par[0]->{test} in BLK @$filter_par[0]->{blk}\n";
        }
      } else {
        print "cannot find the specified block, will run the whole tf\n";
      }
    } elsif (@$filter_par[0]->{test} eq "") {
      die "filter required single test case name to specified; if you want to run whole block please use option -BLK directory!\n";
    }
  } elsif ($type eq 'TS::Block') {
      if (@$filter_par[0]->{blk} ne "" and $obj->{name} ne @$filter_par[0]->{blk}) 
      {
        print "already in the block, cannot to add other block in the filter\n";
      } elsif (@$filter_par[0]->{test} eq "") {
        die "filter required single test case name to specified; if you want to run whole block please use option -BLK directory!\n";
      } else {
        my $case_info = search_expand_case(@$filter_par[0]->{test}, $obj->{name}, "");
        if ($$case_info[0]) {
          foreach my $a2 (@{$obj->case}) {
          if ((ref $a2 eq 'TS::Case' and $a2->{name} eq @$case_info[0]->{case}) or (ref $a2 ne 'TS::Case')) {
            if (ref $a2 eq 'TS::Case') {
              $a2->{name} = @$filter_par[0]->{test};
            }
            push @new_case, $a2;
          }
        }
        delete $obj->{case};
        $obj->{case} = \@new_case;
      } else {
        die "cannnot find the test @$filter_par[0]->{test} in BLK @$filter_par[0]->{blk}\n";
      }
    }
  }
}

sub add_seqfile{
  my $sf = shift;
  die "Cannot find sequence file $sf" unless -f $sf;
  require $sf;
}

sub remove_restart{
  $env->{run}{restart} = 0;
}

sub add_test_param{
  my @param = @_;
  my @p;
  foreach(@param){
    push @p, (split /\s+/, $_);
  }
  push @$tmp_test_params, $_ foreach @p;
}

sub clear_test_param{
  $tmp_test_params = [];
}

sub add_func_param{
  my @param = @_;
  foreach(@param){
    foreach my $o(split /\s+/, $_){
      push @$tmp_func_params, $o;
      if($o =~ /\-cf=(.*)/){
        my $cf_file = $1;
        if(-e $cf_file){
          open IN, "<$cf_file" or die "Cannot open $cf_file";
          while(<IN>){
            if(/^\s*\-log\b/){
              $main::args{log} = 1;
              last;
            }
          }
          close IN;
        }
      }elsif($o == "-log"){
        $main::args{log} = 1;
      }
    }
  }
  if($main::args{log}){
    $main::universe->Config->{log}{type} = "yaml";
    $main::universe->Config->{log}{file} = "log.yml";
  }
}

sub clear_func_param{
  $tmp_func_params = [];
}

# env, config, global management

sub set_env_opt{
  my %opt = @_;
  while(my ($k, $v) = each %opt){
    if($k eq 'setstate'){
      if($main::args{nodefstate} or $main::args{nosetstate}){
        delete $env->{$k};
      }else{
        $env->{$k} = $v;
      }
    }elsif($k eq "gb" || $k eq "mba"){
      if($main::args{nogb}){
        delete $env->{$k};
      }else{
        $env->{$k} = $v;
      }
    }else{
      $env->{$k} = $v;
    }
  }
}

sub save_env_opt{
  my @opt = @_;
  my %opt;
  foreach(@opt){
    $opt{$_} = $env->{$_};
  }
  push @{$env->{opt_save_stack}}, \%opt;
}

sub restore_env_opt{
  my $opt = pop @{$env->{opt_save_stack}};
  while(my ($k, $v) = each %$opt){
    $env->{$k} = $v;
  }
}

sub set_config_const{
  my %opt = @_;
  while(my ($k, $v) = each %opt){
    $config->{const}{$k} = $v;
  }
}

sub set_global_opt{
  my %opt = @_;
  while(my ($k, $v) = each %opt){
    $main::global{$k} = $v;
  }
}

# bg_cfg_data

sub save_cfgdata{
  my $cfg = shift;
  my $file = "cfgdata";
  open OUT, ">$file" or die "Cannot open $file to write $@";
  while(my($k, $v) = each %$cfg){
    if(ref $v eq ""){
      print OUT "$k:$v\n";
    }elsif(ref $v eq "HASH"){
      print OUT "$k:{".(join ",", map{"'$_'=>'$v->{$_}'"} keys %$v)."}\n";
    }elsif(ref $v eq "ARRAY"){
      print OUT "$k:[".(join ",", map {"'$_'"} @$v)."]\n";
    }
  }
  close OUT;
}

sub read_cfgdata{
  my $file = "cfgdata";
  return undef unless -e $file;
  my %input;
  open IN, "<$file" or die "Cannot open $file to read $@";
  while(<IN>){
    chomp;
    s/^\s+|\s+$//g;
    if(/(.*?)\:(.*)/){
      my ($k, $v) = ($1, $2);
      if($v =~ /\[|\{/){
        $input{$k} = eval($v);
      }else{
        $input{$k} = $v;
      }
    }
  }
  close IN;
  return \%input;
}

# helpers

sub is_array_same{
  my ($a1, $a2) = @_;
  my @newa1 = sort @$a1;
  my @newa2 = sort @$a2;
  
  return 0 if $#newa1 != $#newa2;
  
  for(0..$#newa1){
    return 0 if($newa1[$_] ne $newa2[$_]);
  }
  return 1;
}

sub second_2_read{
  my $t = shift || 0;
  
  my ($d, $h, $m, $s) = (0,0,0,0,0);
  $s = $t%60;
  $t = int($t/60);
  $m = $t % 60 if $t;
  $t = int($t/60);
  $h = $t % 24 if $t;
  $d = int($t/24) if $t;
  
  return ($d ? "${d}d ":'').($h || $d ? "${h}h ":'').($m || $h || $d ? "${m}m ":'')."${s}s";
}

sub strip{
  my $str = shift;
  $str =~ s/^\s+|\s+$//g;
  return $str;
}

sub match_os{
  my $os = shift;
  return 1 unless $os;
  my $ok_flag = 0;
  foreach my $o(split /,/, lc($os)){
    my ($neg, $os) = ($o =~ /(\-?)(\w+)/);
    if($neg){
      if($os eq $TS::AppConf::os){
        $ok_flag = 0;
        last;
      }else{
        $ok_flag = 1;
      }
    }else{
      $ok_flag = 1 if $os eq $TS::AppConf::os;
    }
  }
  return $ok_flag;
}

sub read_file_last_line{
  my $file = shift;
  open LOG, "< $file" or die $@;
  my $line;
  while(<LOG>){
    $line = $_;
  }
  chomp($line);
  close LOG;
  return $line;
}

sub write_to_file_add{
  my $file = shift;
  open LOG, ">> $file";
  print LOG @_;
  close LOG;
}

sub write_to_file{
  my $file = shift;
  open LOG, "> $file";
  print LOG @_;
  close LOG;
}

# manage input

sub read_input{
  my ($intro, $opt, $default, $map) = @_;
  print "$intro";
  my $in;
  while(<STDIN>){
    chomp;
    $in = uc($_);
    my $valid = 0;
    if($in eq '' and defined $default){
      $in = $default;
      $valid = 1; # if default was defined, then take blank input as default
    }else{
      for my $o(@$opt){
        if(uc($o) eq $in){
          $valid = 1; # found input in opt array, set valid to true
          last;
        } 
      }
    }
    if($valid){ # if input is valid, exit input and continue program
      last;
    }else{
      print "Invaild option, please type ", (join '|', @$opt), "\n";
    }
  }
  print "\n";
  $in = $map->{$in} if defined $map and %$map;
  return $in;
}

sub read_input_text{
  my ($intro, $regex) = @_;
  print "$intro";
  my $in;
  while(<STDIN>){
    chomp;
    $in = $_;
    if($in ne ''){
      if($regex){
        if($in =~ /$regex/){
          last;
        }else{
          print "Wrong format\n";
        }
      }else{
        last;
      }
    }
  }
  print "\n";
  return $in;
}

##################
# manage output
##################
sub set_output{
  my ($out, $err, $add) = @_;
  no strict "refs";
  open(my $old_out, ">&STDOUT") or die "Can't dup STDOUT: $!";
  open(my $old_err, ">&", \*STDERR) or die "Can't dup STDERR: $!";

  my $write_type = $add ? '>>' : '>';

  open STDOUT, $write_type, $out;
  if($err){
    open STDERR, $write_type, $err;
  }else{
    open STDERR, ">&STDOUT";
  }
  return ($old_out, $old_err);
}

sub restore_output{
  my ($out, $err) = @_;
  no strict "refs";
  open(my $old_out, ">&STDOUT") or die "Can't dup STDOUT: $!";
  open(my $old_err, ">&STDERR") or die "Can't dup STDERR: $!";
  open STDOUT, ">&", \*$out;
  open STDERR, ">&", \*$err;
  eval{
    close $old_out;
    close $old_err;
  };
}

#########################
# tclist
#########################
sub support_tclist_option{
  my $output = `$main::tserver_app -tclist 2>&1`;
  my $support = 1;
  my $rc = getrc($?);
  $support = 0 if $rc == -1 or $rc == 126 or $output =~ /Invalid option/i;
  return $support;
}

sub get_tclist{
  my $tf = shift;
  #my $output = `$main::tserver_app -d=1 -tclist -v=extra -tf=$tf 2>&1`;
  my $output = `$main::tserver_app -d=1 -tclist -v=debug -tf=$tf 2>&1`;
  my @case;
  my $in_test_list = 0;
  foreach(split /\n/, $output){
    chomp();
    if($in_test_list){
      if(/^(\[\w+\]){1,2}\s*([a-zA-Z]+\.?\d+(\.\d+)?)\s*$/){
        push @case, $2;
      }elsif(/Finished test enumeration/i){
        $in_test_list = 0;
        last;
      }
    }elsif(/Printing test list/i){
      $in_test_list = 1;
    }
  }
  return \@case;
}
sub get_tclist_case{
  my $test = shift;
  my $output = `$main::tserver_app -d=1 -tclist -v=debug -test=$test 2>&1`;
  my @case;

  my $in_test_list = 0;
  foreach(split /\n/, $output){
    chomp();
    if($in_test_list){
      if(/^(\[\w+\]){1,2}\s*([a-zA-Z]+\.?\d+(\.\d+)?)\s*$/){
        push @case, $2;
      }elsif(/Finished test enumeration/i){
        $in_test_list = 0;
        last;
      }
    }elsif(/Printing test list/i){
      $in_test_list = 1;
    }
  }
  return \@case;
}

sub get_tclist_count{
  my $tf = shift;
  my $output = `$main::tserver_app -d=1 -tclist -v=debug -tf=$tf 2>&1`;
  my $count = 0;
=cut
[debug] Printing test list:
[debug]         PM401.002
[debug]         PM431.005
[debug] Finished test enumeration
=cut
  my $in_test_list = 0;
  foreach(split /\n/, $output){
    chomp();
    if($in_test_list){
      if(/^\[debug\]\s*[a-zA-Z]+\.?\d+(\.\d+)?\s*$/){
        $count++;
      }elsif(/Finished test enumeration/i){
        $in_test_list = 0;
        last;
      }
    }elsif(/Printing test list/i){
      $in_test_list = 1;
    }
  }
  return $count;
}
#-----------------------------------------------------------------------------
#   Name          : search_expand_case
#   Parameters    : expand_case     a specified test name
#                   blk             the BLK which contains the expand case
#                   tf              the STF which currrently run by -tf=STF
#   Return Values : expand_info     array[0] is hash map for a single
#                                   case, array[0]->case is the case group
#                                   which the expand case belong to in STF
#   Desc          : In STF, use abbreviate case name were used. For a given test,
#                   found it's abbreviate name by this function.
#-----------------------------------------------------------------------------
sub search_expand_case {
  my ($expand_case, $blk, $tf) = @_;
  my $sexpand_case = transfer_case_name($expand_case);
  $blk = lc($blk); $tf = lc($tf);
  my $case, my $output;
  my $tserver = abs_path(dirname(__FILE__).'/../../');
  chdir($tserver);
  $output = `./tserver -tf=$tf -showtest -expand` if ($tf ne "");
  $output = `./tserver -blk=$blk -showtest -expand` if ($tf eq "");
  my @output_array = reverse(split /\n/, $output);
  my $start = 0; my $case_start = 0; my $blk_start = 0;
  my $expand_info = [];
  for my $line (@output_array) {
    if ($blk ne "") {
      if (transfer_case_name($line) eq $sexpand_case and $start!=1)
      { 
        print "found $expand_case in $line\n" if $main::args{debug};
        $start = 1;
        next;
      } elsif (($line =~ /case\:(.*)/i) and $start==1 and $case_start!=1 ) {
        $case = $1;
        print "found matched case in stf $case\n" if $main::args{debug};
        $case_start = 1;
        next;
      } elsif (($line =~ /$blk/i) and $case_start==1) {
        push @$expand_info, {test => $expand_case, case=>$case, blk=>$blk, tf=>$tf};
        last;
      } elsif ($start!=1 or $case_start!=1 or $blk_start!=1 or $line eq "") {
        next;
      } else {
        last;
      }
    } else {
      if (transfer_case_name($line) eq $sexpand_case and $start!=1)
      {
        $start = 1;
        next;
      } elsif (($line =~ /case\:(.*)/i) && $start==1) {
        $case = $1;
        $case_start = 1;
        push @$expand_info, {test => $expand_case, case=>$case, blk=>"N/A", tf=>$tf};
        last;
      } elsif ($start!=1 or $case_start!=1 or $line eq "") {
        next;
      } else {
        last;
      }
    }
  }
  return $expand_info;
}
#-----------------------------------------------------------------------------
#   Name          : transfer_case_name
#   Parameters    : case_name       test case name 
#   Return Values : string          case name 
#   Desc          : transfer kinds of case name to unified format
#                   eg. hdp009.001 to hdp9.1, ak320.001 to ak320.1
#-----------------------------------------------------------------------------
sub transfer_case_name {
  my $case_name = shift;
  $case_name = lc($case_name);
  my @case = split /\./, $case_name;
  @case[0] = string_filter(@case[0]);
  @case[1] = string_filter(@case[1]);
  $case_name = join('.', @case);
  return $case_name;
}
sub string_filter {
  my $string = shift;
  my @string = map substr( $string, $_, 1), 0 .. length($string) -1;
  my $start = 0;
  my @array;
  foreach my $c (@string)
  {
    if ($c =~ /[a-z]/)
    {
      push @array, $c;
      next;
    } elsif ($c =~/[1-9]/) {
      $start = 1;
      push @array, $c;
      next;
    } elsif ($c==0 && $start==1) {
      push @array, $c;
    } elsif ($start!=1) {
      next;
    } elsif (!defined $c) {
      last;
    }
  }
  my $new_string = join('', @array);
  return $new_string;
}

#########################
# Split options by comma
#########################

sub split_option{
  my $str = shift;
  my $delimiter = shift || ",";
  my @option;
  my @chars = split "", $str;
  my @stack;
  my $name = "";
  my $value = "";
  my $quato = 0;
  for(@chars){
    if($quato){
      if($_ eq '"'){
        $quato = 0; # reset quato flag 
      }else{
        push @stack, $_;
      }
    }else{
      if($_ eq '"'){
        $quato = 1; # encount quato, about to find the pair
      }elsif(not $name and $_ eq "="){ # left string of first "=" as name
        $name = join "", @stack;
        @stack = ();
      }elsif($_ eq $delimiter){
        if($name){
          $value = join "", @stack;
        }else{
          $name = join "", @stack;
        }
        $name =~ s/^\s+|\s+$//g; #strip
        $value =~ s/^\s+|\s+$//g; #strip
        push @option, {name=>$name, value=>$value} if $name;
        @stack = ();
        $name = "";
        $value = "";
      }else{
        push @stack, $_;
      }
    }
  }
  if($name){
    $value = join "", @stack;
  }else{
    $name = join "", @stack;
  }
  $name =~ s/^\s+|\s+$//g; #strip
  $value =~ s/^\s+|\s+$//g; #strip
  push @option, {name=>$name, value=>$value} if $name;
  return \@option;
}

sub getrc{
  my $rc = shift;
  $rc = $? unless defined $rc;
  if ($rc == -1) {
    print "Error: $!\n";
  }elsif($rc & 127) {
    printf "Error: child died with signal %d, %s coredump\n", ($rc & 127),  ($rc & 128) ? 'with' : 'without';
  }else {
    $rc = $rc >> 8;
  }
  if($rc == 126){
    print "Error: $!\n";
  }
  return $rc;
}

#################
# Log Operation #
#################
sub read_last_log{
  my $logtype = $TS::Universe::Config->{log}{type};
  my $sub = "read_last_log_$logtype";
  $sub = \&$sub;
  $sub->(@_);
}

sub read_last_log_yaml{
  my $log = $TS::Universe::Config->{log}{file};
  my $result = {};
  my $mtime = -e $log ? (stat($log))[9] : 0;
  if(not -e $log){
    print "$log doesn't exist\n" if $main::args{debug};
    return $result;
  }elsif($mtime < $main::global{tsw_stime}){
    print "$log hasn't been updated\n" if $main::args{debug};
    return $result;
  }

  use YAML::Tiny;
  my $last = YAML::Tiny->read($log);
  unless($last and @$last and %{$last->[-1]}){
    print "log.yml is empty\n";
    return $result;
  }
  $last = $last->[-1];
  my %tests;
  $result->{results} = $last->{results};
  $result->{command} = $last->{command};
  $result->{tests} = [];
  foreach my $t(@{$last->{tests}}){
    if($t->{start}){
      $tests{$t->{start}} = {id=>$t->{id}, device_id=>$t->{device_id}};
    }elsif($t->{end}){
      if($tests{$t->{end}}){ # key exists
        my $status = $t->{result};
        my $event_failure = undef;
        if($status =~ /\+$/){
          $status = $`;
          $event_failure = $&;
        }
        $tests{$t->{end}}{elapsed} = $t->{elapsed};
        $tests{$t->{end}}{result} = $status;
        $tests{$t->{end}}{event_failure} = $event_failure;
        $result->{results}{event_failure}++ if $event_failure;
        if (ref $t->{errors} eq "ARRAY") {
            $tests{$t->{end}}{errors} = $t->{errors} unless $t->{errors}[0] eq "No Errors Reported";
        } else {
            $tests{$t->{end}}{errors} = $t->{errors} if $t->{errors} and $t->{errors} !~ /No Errors Reported/;
        }
        my $test = delete $tests{$t->{end}};
        push @{$result->{tests}}, {test=>$test};
      }
    }elsif($t->{test}){
      my $status = $t->{test}{result};
      my $event_failure = undef;
      if($status =~ /\+$/){
        $status = $`;
        $event_failure = $&;
      }

      $t->{test}{result} = $status;
      $t->{test}{event_failure} = $event_failure;
      $result->{results}{event_failure}++ if $event_failure;

      push @{$result->{tests}}, {test=>$t->{test}};
    }
  }
  return $result;
}

sub read_last_log_text{
  my $log = $TS::Universe::Config->{log}{file};
  my $result = {};
  return $result unless -e $log;
  open TIDIN, "< $log" or die "Cannot open log file $log";
  while(<TIDIN>){
    chomp;
    if(/tserverlite/){
      # clear $result
      %$result = ();
      $result->{command} = $_;
    }elsif(/^(\w+\d+(.\d+)?)\s+\S+\s+(Pass|Skip|Fail|Abort|Hang)(\+?)\s+([\d\.]+)/){
      $result->{results}{lc($3)}++;
      $result->{results}{count}++;
      $result->{results}{event_failure}++ if $4;
      push @{$result->{tests}}, {test=>{id=>$1, result=>$3, event_failure=>$4, elapsed=>$5*1000}};
    }
  }
  close TIDIN;
  return $result;
}

sub find_str_from_rstlog{
  my $str = shift;
  my $has = 0;
  my $log = $TS::Universe::Config->{log}{file};
  open TIDIN, "< $log" or die "Cannot open log file $log";
  while(<TIDIN>){
    if(/$str/){
      $has = 1;
      last;
    }
  }
  close TIDIN;
  return $has;
}

############################
# system
############################

sub is_root{
  my $usr = `id`;
  my $is = 0;
  if($? == 0 and $usr =~ /^uid=0\(root\)/){
    $is = 1;
  }
  return $is;
}

sub has_grub_mem{
  my $grub = `cat /etc/default/grub`;
  my $has = 0;
  #GRUB_CMDLINE_LINUX="mem=2048M iommu=off"
  #GRUB_CMDLINE_LINUX_DEFAULT="quiet text mem=1024M iommu=off"
  if($? == 0 and $grub =~ /GRUB_CMDLINE_LINUX_DEFAULT="[^"]*mem=[^"]*"/){
    $has = 1;
  }
  return $has;
}

sub is_dir_writable{
  my $filename = "isdirwritabletestfile".rand(1000);
  my $rc = system("touch $filename");
  my $writable = 0;
  if($rc == 0 and -e $filename){
    $writable = 1;
    unlink $filename;
  }
  return $writable;
}

sub is_gpp_installed{
  # g++ make, apt-get list
  #my $gpp = `apt list 2>&1 | egrep "\bg++\b" | grep installed `;
  my $gpp = `apt list 2>&1`;
  if($? == 0){
    my $p = "++";
    return 1 if $gpp =~ /^g$p\b.*?\binstalled\b/m;
  } 
  return 0;
}

sub is_make_installed{
  my $make = `apt list 2>&1`;
  if($? == 0){
    return 1 if $make =~ /^make\b.*?\binstalled\b/m;
  }
  return 0;
}

sub bp_pre_env_test{
  return unless $TS::AppConf::is_linux;
  if(TS::Util::has_grub_mem()){
    print "[1/5] grub test pass\n";
  }else{
    die "[1/5] grub test failed
Please modify you grub, change default memory setting and restart:
  \$vi /etc/default/grub
  \$update-grub2
  \$reboot
";
  }
  if(TS::Util::is_root()){
    print "[2/5] root test pass\n";
  }else{
    die "[2/5] root test failed
Please run tserver as root\n";
  }
  if(TS::Util::is_dir_writable()){
    print "[3/5] dir test pass\n";
  }else{
    die "[3/5] dir test failed
Do not have write permission in current directory\n";
  }
  if(TS::Util::is_gpp_installed()){
    print "[4/5] g++ test pass\n";
  }else{
    die "[4/5] g++ test failed
Please install g++ firstly:
  apt-get install g++
";
  }
  if(TS::Util::is_make_installed()){
    print "[5/5] make test pass\n";
  }else{
    die "[5/5] make test failed
Please install make firstly:
  apt-get install make
";
  }
}


1;

__END__
