#!/usr/bin/perl

use strict;
use File::Basename;
use File::Copy;
use lib dirname(__FILE__)."/perllib";
use lib dirname(__FILE__)."/../../external/non-amd/release/perl/lib";
use Getopt::Long;
use XML::Simple;
use Data::Dumper;
use lib "."; 

use TS::Util;
use TS::TestFile;
use TS::Universe;
use SimpleTime;
use subs qw/printlog printlogl printlogd printlogdl print_rstlog print_rstlogl print_rstlogd print_rstlogdl print_txtlog print_txtlogl print_txtlogd print_txtlogdl/;
our $universe = TS::Universe->new();
our $config = $universe->Config();
our $env = $universe->Env();

use TS::AppConf;
our $tserver_app = "$TS::AppConf::cmd_pre$TS::AppConf::tserver_app";
our $tool_app = "$TS::AppConf::cmd_pre$TS::AppConf::tool_app";
our $erroridtmplog = "errorid.tmp";
our %cmd_var;
our $tsl_param;
our %global;
our @device_list;
our @device_sku;
our $dgpu_device;
our $boot_aspm; 
our $loop_count = 1;
our $scriptloop_start_time;
our $prev_loop_time;

use MyCli;
our @suite_defination_files;
our @arg_format;
our @gemini_sku;
our @SSG_sku;
our @pro_sku;
our @pcie_sku;
our @no_baco_sku;
our @no_bamaco_sku;

our %RC_DEF = (OK=>0, FAIL=>1, SYS_ERROR=>2, INVALID_TEST=>62);
$global{RC} = $RC_DEF{OK};
$global{tsw_stime} = time; #tserver start time

main();

sub main{
  init();
  open_export_file();
  read_tfs(); # read test files
  run_test(); # run test
  close_export_file();
}

sub init{
  # get original options
  my @opt;
  if($ENV{ZEROFRAMEBUFFER}){
    push @ARGV, "-zfb";
  }
  for(@ARGV){
    if(/\s+/){
      if(/(.+)=(.+)/){
        push @opt, "$1=\"$2\"";
      }else{
        push @opt, "\"$_\"";
      }
    }else{
      push @opt, $_;
    }
  }

  my $org_options = join " ", @opt;
  my $curTest;

  if ($org_options =~ /external_build/){
    my $xmlfile=dirname($0)."/suite_flow.xml";
    if (-e $xmlfile){
      if ($org_options =~ /boardtest=(\S+)/){
         $curTest = $1;
      }

      my $sku = get_dgpu_sku();
      if ($sku eq ""){
        print "ERROR: This SKU does not support ".$curTest." !\n";
        exit 2;
      }
      $sku = lc($sku);
      my $supportFlag = 0;

      my $testSeqT = XML::Simple->new(KeyAttr => "test_sequence");
      my $testSeqXmlT = $testSeqT->XMLin($xmlfile);
      my @allTestSequenceT = @{$testSeqXmlT->{"test_sequence"}};

      foreach my $testSequence (@allTestSequenceT){
        if ($testSequence->{"name"} =~ /\b$curTest\b/){
          if (lc($testSequence->{"supported_sku"}) eq "any"){
              $supportFlag = 1;
          }else{
            my @skulist = split(/,/, lc($testSequence->{"supported_sku"}));
            foreach my $skul (@skulist){
              if($skul =~ /\b$sku\b/){
                $supportFlag = 1;
              }
            }
          }
        }
      }
      if(!$supportFlag){
         print "ERROR: This SKU does not support ".$curTest." !\n";
         exit 2;
      }
    }else{
      print "ERROR: suite_flow.xml file not found!\n";
      exit 2;
    }
  }

  # load suite pl
  @suite_defination_files = glob "suite_*.pl";
  printdl (join "\n", @suite_defination_files);
  for(@suite_defination_files){
    require $_;
  }

  # read options, Cli configuration
  @arg_format = $universe->get_arg_format();
  MyCli::init();
  # config setting
  $universe->Config->{log}{export} = $args{export} if $args{export};
  $universe->Config->{log}{type} = $args{logtype} if $args{logtype};
  $universe->Config->{log}{file} = $args{logfile} if $args{logfile};
  my @cfs;
  push @cfs, "tserver.cf" if $args{defaultcf};
  if($args{cf}){
    my $c = $args{cf};
    push @cfs, @$c;
  }
  for my $cf(@cfs){
    open IN, "<$cf" or die "Cannot open $cf";
    while(<IN>){
      if(/^\s*\-log\b/){
        $args{log} = 1;
      }elsif(/^\s*\-tid\b/){
        $global{tid} = 1;
      }
    }
    close IN;
  }

  if($args{log}){
    $universe->Config->{log}{type} = "yaml";
    $universe->Config->{log}{file} = "log.yml";
  }

  $global{zfb} = 1 if $args{zfb};
  $global{log} = 1 if $args{log};

  # test os and run os specific code before parse command line options
  run_os_spec($org_options);

  # move tserverlite call after os specs
  $global{support_tclist_option} = support_tclist_option();

  # bp suite
  if(exists $universe->Config->{params}{boardtest}){
    unlink $universe->Config->{log}{file} if -e $universe->Config->{log}{file};
    unlink "testid.log" if -e "testid.log";
    unlink "log.txt" if -e "log.txt";
  }

  # other suite, rotation need to added to caller scripts, not this script
  #if(-e $testidlog){ # add timestamp to testid.log
  #  my $timestamp = SimpleTime::time_2_str(time - int((-M $testidlog)*86400), "%Y%m%d%H%M%S");
  #  rename $testidlog, $testidlog.".$timestamp";
  #}
  
  $global{old_logyml} = backup_rstlog();
}

sub run_test{
  printdl "About to run test";
  # clear tmp file
  unlink $universe->Config->{log}{file} if $args{clearlog};
  # remove driver
  if ($args{rmdriver}){
    printdl "Unload and remove driver";
    `rmmod amddiag`;
    `find /lib/modules -name amddiag.ko -delete`;
  }

  # add delimeter
  print_rstlogl("\n", "=" x 20, SimpleTime::time_2_iso(), "=" x 20); # only for testid.log
  if(defined $args{showblock}){
    my $out_prefix = "";
    my $testfiles = $universe->Config->{test_files};
    if($args{showblock} eq ''){
      for my $tf(sort keys %$testfiles){
        printl $out_prefix, $tf, ":";
        $out_prefix = "  ";
        for my $act(@{$testfiles->{$tf}->actions}){
          printl $out_prefix, $act->name if ref $act eq 'TS::Block';
        }
        $out_prefix = "";
      }
    }else{ # a tf file
      (print "Cannot find tf file $args{showblock}\n") && ($global{RC} = $RC_DEF{FAIL}) && exit $RC_DEF{FAIL} unless $universe->Config->{test_files}{$args{showblock}};
      for(@{$universe->Config->{test_files}{$args{showblock}}->actions}){
        printl $_->name if ref $_ eq 'TS::Block';
      }
    }
  }elsif(defined $args{showtest}){
    my $testfiles = $universe->Config->{test_files};
    my $case_list;
    my %test;
    if($args{showtest} eq ''){
      for my $tf(keys %$testfiles){
        printl "tf:$tf" if defined $args{expand} and (not defined $args{block});
        for my $act(@{$testfiles->{$tf}->actions}){
          my $type = ref $act;
          if($type eq 'TS::Case'){
            $test{$act->name}++;
            if(defined $args{expand} and (not defined $args{block})){
              printl "case:$act->{name}";
              $case_list = get_tclist_case($act->{name});
              printl join "\n", @$case_list;
            } 
          }elsif($type eq "TS::Block"){
            if (($args{block} and $act->{name} eq lc($args{block})) or (not defined $args{block})){
              printl"blk:$act->{name}" if defined $args{expand};
            for my $act2(@{$act->actions}){ 
              $test{$act2->name}++ if ref $act2 eq 'TS::Case';
                if(defined $args{expand}){
                  printl "case:$act2->{name}" if ref $act2 eq 'TS::Case';
                  $case_list = get_tclist_case($act2->{name});
                  printl join "\n", @$case_list;
                }
              }
            }
          }
        }
      }
    }else{
      if(exists $testfiles->{$args{showtest}}){ #this is a tf
        printl "tf:$testfiles->{$args{showtest}}->{name}" if defined $args{expand};
        for my $act(@{$testfiles->{$args{showtest}}->actions}){
          my $type = ref $act;
          if($type eq 'TS::Case'){
            $test{$act->name}++;
            if(defined $args{expand}){
              printl "case:$act->{name}";
              $case_list = get_tclist_case($act->{name});
              printl join "\n", @$case_list;
            }
          }elsif($type eq "TS::Block"){
            printl "blk:$act->{name}" if defined $args{expand};
            for my $act2(@{$act->actions}){
              $test{$act2->name}++ if ref $act2 eq 'TS::Case';
              if(defined $args{expand}) {
                printl "case:$act2->{name}" if ref $act2 eq 'TS::Case';
                $case_list = get_tclist_case($act2->{name});
                printl join "\n", @$case_list;
              }
            }
          }
        }
      }elsif(exists $universe->Config->{blocks}{$args{showtest}}){
        printl "blk:$universe->Config->{blocks}{$args{showtest}}->{name}" if defined $args{expand};
        for my $act2(@{$universe->Config->{blocks}{$args{showtest}}->actions}){
          $test{$act2->name}++ if ref $act2 eq 'TS::Case';
          if(defined $args{expand}) {
            printl "case:$act2->{name}" if ref $act2 eq 'TS::Case';
            $case_list = get_tclist_case($act2->{name});
            printl join "\n", @$case_list;
          }
        }
      }

    }
    printl join "\n", sort keys %test if (not defined $args{expand});
  }elsif($args{seqfile}){
    printdl "About to add sequence file $args{seqfile}";
    add_seqfile($args{seqfile});
    generate_and_run_test_list();
    generate_summary();
  }elsif($args{boardtest}){
    #TS::Util::bp_pre_env_test();
    printdl "About to find $args{boardtest}";
    unlink "prodinfo.log" if -e "prodinfo.log";
    # add test actions to list
    $universe->Config->{params}{boardtest}{options}{$args{boardtest}}->();

    # transfer to tf format and run
    generate_and_run_test_list();
    generate_summary();
  }elsif($args{slttest}){
    printdl "About to find $args{slttest}";
    unlink "prodinfo.log" if -e "prodinfo.log";
    # add test actions to list
    $universe->Config->{params}{slttest}{options}{$args{slttest}}->();

    # transfer to tf format and run
    generate_and_run_test_list();
    generate_summary();
  }elsif($args{func}){
    if(defined &{"main::$args{func}"}){
      my $func = \&{"main::$args{func}"};
      $func->();
      generate_and_run_test_list();
      generate_summary();
    }else{
      my $funcs = $universe->Config()->{funcs};
      if(exists $funcs->{$args{func}}){
        my $func = $funcs->{$args{func}};
        build_test_queue($func);
        generate_and_run_test_list();
        generate_summary();
      }else{
        print "Cannot find specified func\n";
        exit 2;
      }
    }
  }elsif($args{block}){
    $args{block} = lc ($args{block});
    add_block($_) for(split /,/, $args{block});
    generate_and_run_test_list();
    generate_summary();
  }elsif($args{tf}){
    #set_env_opt("setstate"=>1, gb=>1);
    #set_config_const("clock-guardband" =>2, "mem-guardband"=>3);
    for(split ',', $args{tf}){
      for(glob($_)){
        add_tf($_);
      }
    }
    generate_and_run_test_list();
    generate_summary();
  }elsif($args{test}){
    add_test($args{test});
    generate_and_run_test_list();
    generate_summary();
  }elsif($args{d} and $args{d} eq "?"){
    my $cmd = "$tserver_app -d=?";
    my $rc = system($cmd);
    exit $rc;
  }
}

sub generate_and_run_test_list{
  my $queue = $env->{action_queue};

  # get gopt
  read_gopt_from_params([split / +/, $tsl_param]);
  read_gopt_from_params(["-cf=tserver.cf"]) if -e "tserver.cf" and $args{defaultcf};
  get_gopt_by_queue($queue); # set tid,d,eofe in case they were set in params

  my @tf; #store test cases
  # inherit params and cfs
  my @current_params;
  my @current_cf;
  my @block_params;
  my @block_cf;
  my @tf_params;
  my @tf_cf;
  my @ctf_queue;
  my %ctf_param;
  my $run_ctf_flag = 0;

  # add init suite state to queue
  if($args{defstate} or $env->{setstate}){ # initial state setting before any test.
    $main::env->{setstate} = 1;
    $main::env->{"gb"} = 1;
    if(ref $queue->[0] eq "CODE"){
      my $code = shift @$queue;
      unshift @$queue, new TS::App(app=>"\$tool", param=>"-ppmode=");
      unshift @$queue, $code;
    }else{
      unshift @$queue, new TS::App(app=>"\$tool", param=>"-ppmode=");
    }
  }

  $global{prog_count} = get_prog_count_by_queue($queue);
  $global{prog_current_sn} = 0;
  
  sub run_action{
    my $action = shift;
    my $class = ref $action;
    if($class eq 'TS::App'){
      # if encounter system call, clear cache
      printdl "Encounter system call";
      run_cached_case(\@current_params, \@current_cf, \@tf);
      return if $args{tclist};
      
      if($action->is_tool_mode()){ # if it's tool mode setting, set just once.
        return if($args{defstate} and $env->{set_state_count}); 
        $env->{set_state_count}++ if($args{defstate} or $env->{setstate});
      }      
      
      $global{prog_current_sn}++;
      my $cmd_status = sprintf("CMD%03d.PD", $global{prog_current_sn});
      if($global{pr}){
        write_to_file($erroridtmplog, $cmd_status);
      }
      printl sprintf("CMD%03d:", $global{prog_current_sn}), $action->get_cmd;
      print_rstlogl sprintf("CMD%03d:", $global{prog_current_sn}), $action->get_cmd;
      print_txtlogl sprintf("CMD%03d:", $global{prog_current_sn}), $action->get_cmd;
      printlogl sprintf("CMD%03d:", $global{prog_current_sn}), $action->get_cmd;
      #my @old_handlers = set_output("testid.log", undef, 1) if $global{tid} or $global{log};
      my $rc = 0;
      my $output = [];
      if(not $args{dryrun}){
        ($rc, $output) = $action->run();
        $rc = getrc($rc);
        if($output and @$output){
          foreach(@$output){
            print_txtlog($_);
            print_rstlog($_);
          }
        }
      }
      if ($rc != 0)
      {
        $global{app_fail_flag}++ ;
      }
      #restore_output(@old_handlers) if $global{tid} or $global{log};
      if($global{pr}){
        if($rc != 0){
          my $last_line = read_file_last_line($erroridtmplog);
          if(read_file_last_line($erroridtmplog) eq $cmd_status){
            write_to_file($erroridtmplog, sprintf("CMD%03d.PA", $global{prog_current_sn}));
          }
        }else{
          write_to_file($erroridtmplog, "PASS");
        }
      }
      if($rc != 0 and $global{eofe} and not $action->ignore_rc()){
        printl "[External Command] Got error with return code $rc, about to exit.";
        printlogdl "[External Command] Got error with return code $rc, about to exit.";
        print_rstlogdl "[External Command] Got error with return code $rc, about to exit.";
        print_txtlogl "[External Command] Got error with return code $rc, about to exit.";
        $global{RC} = ($rc == -1) ? 2 : $rc;
        exit_with_fail_screen($rc);
      }
      printdl "Return Code:$rc", "\n", "=" x 60;
      print_rstlogdl "Return Code:$rc\n";
      print_txtlogdl "Return Code:$rc\n";
      printlogdl "Return Code:$rc", "\n", "=" x 60;
      printdl;
    }elsif($class eq 'TS::Case'){
      return if $action->nozfb() and $global{zfb};
      my @new_cf = (@tf_cf, @block_cf, @{$action->cf});
      my @new_param = (@tf_params, @block_params, @{$action->param});
      if($action->master()){ # master only case
        push @new_param, get_master_device_opt();
      }
      # if parameter changed or encount restart flag, clear cache
      if((not is_array_same(\@current_params, \@new_param) or not is_array_same(\@current_cf, \@new_cf)) or $action->restart or $action->retry){
        printdl "param changed or restart encount" if @tf;
        run_cached_case(\@current_params, \@current_cf, \@tf);
        @current_cf = (@new_cf);
        @current_params = (@new_param);
      }
      if($action->retry){
        my $old_rstlog = backup_rstlog();
        for my $count(1..$action->retry){
          remove_rstlog();
          run_cached_case([@new_param], [@new_cf], [$action->name], ($action->retry - $count), $action->retry_type);
          # get case status from tidlog
          my $status = get_last_result_from_rstlog();
          my $retry_type = $action->retry_type;
          if(not $status or $status !~ /$retry_type/i or $count >= $action->retry){
            last;
          }
          for(qw/pass fail abort hang skip/){
            if(lc($status) eq $_){
              $global{result}{lc($status)}--;
              $global{result}{count}--;
              $global{plan_case_count}--;
            }
          }
          if($retry_type eq "FAIL"){
            open OUT, ">>failretry.log" or die "Cannot open file failretry.log to write $!";
            print OUT $action->name, "\n";
            close OUT;
          }
        }
        my $tmp_rstlog = backup_rstlog();
        recover_rstlog($old_rstlog);
        append_file_to_rstlog($tmp_rstlog);
        unlink $tmp_rstlog;

        @current_cf = ();
        @current_params = ();
        @tf = ();
      }else{
        push @tf, $action->name;
      }
    }elsif($class eq 'TS::Block'){
      return if $action->nozfb() and $global{zfb};
      my @old_tf_params = @tf_params;
      
      my $tf = get_tf_by_block($action->name); # add tf level params
      @tf_params = @{$tf->param} if not @tf_params and $tf;
      
      @block_params = @{$action->param};
      if($action->master()){ # master only case
        push @block_params, get_master_device_opt();
      }
      @block_cf = @{$action->cf};
      if(not $run_ctf_flag and $action->name =~ /^CTF|CTF$/i){
        if(not @ctf_queue){
          $ctf_param{tf_params} = [@tf_params];
          $ctf_param{block_params} = [@block_params];
          $ctf_param{block_cf} = [@block_cf];
          push @ctf_queue, $action;
          return;
        }
      }else{
        for my $a(@{$action->actions}){
          run_action($a);
        }
      }
      @block_params = ();
      @block_cf = ();
      @tf_params = @old_tf_params;
    }elsif($class eq 'TS::TestFile'){
      @tf_params = @{$action->param};
      for my $a(@{$action->actions}){
        next if ref $a eq 'TS::Block' and $a->tf_ex();
        run_action($a);
      }
      @tf_params = ();
    }elsif($class eq 'CODE'){
      printdl "Encounter system call";
      run_cached_case(\@current_params, \@current_cf, \@tf);
      return if $args{tclist};
      $action->();
    }
  }

  $args{scriptloop} ||= 1; #script loop
  foreach(1..$args{scriptloop}){
    loop_count_start() if ($args{loopdiff});
    foreach my $a(@$queue){
      run_action($a);
    }
    run_cached_case(\@current_params, \@current_cf, \@tf); 
    loop_count_stop()  if ($args{loopdiff});
  }
  
  if(@ctf_queue and not $args{noctf}){
    my $ctf_confirm_flag = 1;


    my $ctf_block  = $ctf_queue[0]->name;


    if ($ctf_block eq "gpu_ctf"){
       printl "Testing hardware thermal protection, it is GPU ASIC CTF";
    } elsif( $ctf_block eq 'lcs_ctf' ){
       printl "Testing hardware thermal protection, it is LIQUID CTF";
    }


    $ctf_confirm_flag = read_input(
"Please confirm that you wish to run the CTF test

If successful:
 - There will be NO display
 - Fan will spin at high RPM

1) Yes
2) No
", [1,2], undef, {1=>1, 2=>0}) unless $args{tclist};
    if($ctf_confirm_flag){
      $run_ctf_flag=1;
      @tf_params = @{$ctf_param{tf_params}};
      @block_params = @{$ctf_param{block_params}};
      @block_cf = @{$ctf_param{block_cf}};
      run_action($_) foreach @ctf_queue;
      run_cached_case(\@current_params, \@current_cf, \@tf);
    }
  }
}

sub get_tf_by_block{
  my $b = shift;
  foreach my $tf(values %{$config->{test_files}}){
    foreach my $act(@{$tf->{actions}}){
      if(ref $act eq "TS::Block" and $act->name eq $b){
        return $tf;
      }
    }
  }
  return undef;
}

sub build_test_queue{
  my $obj = shift;
  my $queue = $env->{action_queue};
  my $ref = ref $obj;
  
  if($ref eq 'TS::Func'){ # need to push each func param to each block and tests in this func
    my $oldfunc = $env->{current_func};
    $obj->param([@{$obj->param}, @{$oldfunc->param}]) if($oldfunc); # merge params
    $env->{current_func} = $obj;
    for my $item(@{$obj->list()}){
      build_test_queue($item);
    }
    $env->{current_func} = $oldfunc; # restore old func
  }elsif($ref eq 'TS::Block'){
    my $oldfunc = $env->{current_func};
    if($oldfunc){ # merge old func's params
      for(@{$oldfunc->param}){
        $obj->add_param($_);
      }
    }
    push @$queue, $obj;
  }elsif($ref eq 'TS::Case'){
    my $oldfunc = $env->{current_func};
    if($oldfunc){ # merge old func's params
      for(@{$oldfunc->param}){
        $obj->add_param($_);
      }
    }
    push @$queue, $obj;
  }elsif($ref eq ''){ # text
    if($obj =~ /BLK\s+(\S+)(.*)/){
      my $name = $1;
      my $option = $2;
      my $block = $universe->Config()->{blocks}{$name};
      unless($block){
        warn "Cannot find block $block";
        return;
      }
      $block = $block->clone();
      for my $par(split /\s+/, $option){
        next unless $par;
        $block->add_param($par);
      }
      build_test_queue($block);
    }elsif($obj =~ /TEST\s+(\S+)(.*)/){
      my $name = $1;
      my $option = $2;
      my @case_param;
      for my $par(split /\s+/, $option){
        next unless $par;
        push @case_param, $par;
      }
      my $case = new TS::Case(name=>$1, param=>\@case_param);
      build_test_queue($case);
    }elsif($obj =~ /FUNC\s+(\S+)(.*)/){
      my $name = $1;
      my $func = $universe->Config()->{funcs}{$name};
      build_test_queue($func);
    }
  }else{
    push @$queue, $obj;
  }
}

sub exit_with_fail_screen{
  my $rc = shift;
  printl get_result_ascii("FAIL");
  if(not $args{dryrun}){
    my $result = TS::Util::read_last_log();
    if($result->{results}{event_failure}){
      my ($bkg, $rst) = get_term_bkg_rst("FAIL");
      printl "$bkg"."Suite Failed, found event error.$rst";
      print_rstlogl "Suite Failed, found event error.";
      print_txtlogl "Suite Failed, found event error.";
    }
  }
  exit $rc;
}

sub generate_summary{
  return if $args{tclist};

  my $total = 0;
  $global{plan_case_count} ||= 0;
  $global{actual_case_count} = $global{result}{count} || 0;
  $global{result}{not_run} = $global{plan_case_count} - $global{actual_case_count};
  $global{result}{not_run} = 0 if $global{result}{not_run}<0;
  $global{result}{event_failure} ||= 0;

  my $result_ascii = '';
  if(($global{tsl_fail_flag} and $global{result}{not_run}) # rc > 0 and exists no-run case 
      || $global{result}{fail}     # has fail
      || $global{result}{abort}    # has abort
      || $global{signal_fail_flag} # subset of tsl_fail_flag
      || $global{app_fail_flag}    # external call apps file, example agt_internal
    ){
    $result_ascii = get_result_ascii("FAIL");
    $global{RC} = $RC_DEF{FAIL};
  }elsif($global{tsl_fail_flag}){# and $global{result}{pass} == 0){
    $result_ascii = get_result_ascii("FAIL");
    $global{RC} = $RC_DEF{FAIL};
  }elsif($global{result}{skip}){
    $result_ascii = get_result_ascii("PASS");
    $result_ascii .= "\n".get_result_ascii("with SKIP");
    $global{RC} = $RC_DEF{OK};
  }else{ #pass
    $result_ascii = get_result_ascii("PASS");
    $global{RC} = $RC_DEF{OK};
  }
  printl $result_ascii;
  printl;
  for(qw/Pass Fail Abort Skip/){
    $global{result}{lc($_)} ||= 0;
    printl "Total $_:\t".$global{result}{lc($_)};
    print_rstlogl "Total $_:\t".$global{result}{lc($_)};
    print_txtlogl "Total $_:\t".$global{result}{lc($_)};
  }
  if($global{result}{not_run}){
    printl "Total Not-Run:\t".$global{result}{not_run};
    print_rstlogl "Total No-Run:\t".$global{result}{not_run};
    print_txtlogl "Total No-Run:\t".$global{result}{not_run};
  }
  if($global{result}{event_failure}){
    printl "Event Failure:\t".$global{result}{event_failure};
    print_rstlogl "Event Failure:\t".$global{result}{event_failure};
    print_txtlogl "Event Failure:\t".$global{result}{event_failure};
  }

  if ($global{signal_fail_flag})
  {
    printl "Total Signal Fail:\t".$global{signal_fail_flag};
    print_rstlogl "Total Signal Fail:\t".$global{signal_fail_flag};
    print_txtlogl "Total Signal Fail:\t".$global{signal_fail_flag};
  }

  if ($global{app_fail_flag})
  {
    printl "Total App Fail:\t".$global{app_fail_flag};
    print_rstlogl "Total App Fail:\t".$global{app_fail_flag};
    print_txtlogl "Total App Fail:\t".$global{app_fail_flag};
  }

  printl "Elapsed Time:\t".second_2_read(time-$start_time);
  print_rstlogl "Elapsed Time:\t".second_2_read(time-$start_time);
  print_txtlogl "Elapsed Time:\t".second_2_read(time-$start_time);
}

sub save_result{
  return if $args{dryrun} or $args{disable_global_result};
  my $result = TS::Util::read_last_log();
  if( $result and %$result and $result->{results}){
    for(qw/count pass fail abort hang skip/){
      $global{result}{$_} = 0 if not defined $global{result}{$_};
      $global{result}{$_} += $result->{results}{$_} if defined $result->{results}{$_}
    }
    #  back-compatibility, going to remove if nobody use testid.log
    if($global{tid}){
      for my $t(@{$result->{tests}}){
        my $elap = $t->{test}{elapsed};
        $elap =~ s/[^\d\.]//g;
        $elap = $elap/1000;
        print_rstlogl("$t->{test}{id}    [$t->{test}{device_id}] $t->{test}{result}    $elap sec.");
        if($t->{test}{errors}){
            print_rstlogl("error exist");
            if(ref $t->{test}{errors} eq "ARRAY") {
                for my $error(@{$t->{test}{errors}}) {
                        print_rstlogl("ERROR1: $error");
                    }
            }
            else {
                print_rstlogl("ERROR2: $t->{test}{errors}");
            }
        }
      }
    }
  }
}

sub run_cached_case{
  my ($params, $cf, $tf, $retry, $retry_type) = @_;
  #$params = [@$params]; # avoid overwrite
  my %flag;
  push @$params, $tsl_param if $tsl_param; #put cmd line parameter after other params
  unshift @$params, "-cf=tserver.cf" if -e "tserver.cf" and $args{defaultcf};
  if(@$tf){
    # create tf file
    my $tmp_tf_name = "tserver.tmp.tf";
    create_test_file($tmp_tf_name, $tf);

    if($args{tclist}){ #display tclist and return
      if($global{support_tclist_option}){
        my $list = get_tclist($tmp_tf_name);
        print join "\n", @$list;
      }else{
        print join "\n", @$tf;
      }
      printl unless $args{tclist};
      printl;
      @$params = ();
      @$cf = ();
      @$tf = ();
      return;
    }
    
    # creat cf files
    my @configuration;
    my @config_files;
    for(@$cf){
      printdl $_;
      my $cf = "tserver.tmp.$_.cf";
      push @config_files, $cf;
      create_config_file($cf, $_);
      push @configuration, @{$universe->Config()->{cfs}{$_}};
    }
    for my $p(@$params){ # store predefined cf files to @configuration for output
      if($p =~ /\-cf=(\S+)/){
        my $f = $1;
        open CF, "<$f";
        while(<CF>){
          chomp;
          s/^\s+|\s+$//g;
          s{//.*}{};
          push @configuration, $_ if $_ ne '';
        }
        close CF;
      }
    }

    # count cases
    if($global{support_tclist_option}){
      $global{plan_case_count} += get_tclist_count($tmp_tf_name);
    }else{
      $global{plan_case_count} += @$tf; # count cases
    }
    
    # construct command
    my @precfs = map {"-cf=$_"} @config_files;
    my $cmd_param = join ' ', (@$params, @precfs, "-tf=$tmp_tf_name");
    $cmd_param .= " -log" unless $args{log};
    printdl "params: @$params";
    printlogdl "params: @$params";
    printdl "cfs: @$cf";
    printlogdl "cfs: @$cf";
    # print out all cf contents
    my $cmd = "$tserver_app $cmd_param";
    my $configuration = "    conf:\n". join '', map{"       $_\n"} @configuration;
    chomp($configuration);
    my $tests = "    tests:\n". join "\n", map{"       $_"} @$tf;
    # run command
    printl $cmd;
    printlogl $cmd;
    print_rstlogl $cmd, " (".time_2_iso().")" if $global{tid};
    print_txtlogl $cmd;
    printl $configuration;
    printlogl $configuration;
    printl $tests;
    printlogl $tests;

    my $rc = 0;
    $rc = getrc(system($cmd)) if not $args{dryrun};
    if ($rc > 1)
    {
      printl "return code:\t".$rc;
      print_rstlogl "Return Code:$rc\n";
      print_txtlogl "Return Code:$rc\n";
      $global{signal_fail_flag}++ ;
    }
    $global{tsl_fail_flag}++ if $rc;
    
    printdl "Return Code:$rc";
    print_rstlogdl "Return Code:$rc\n";
    print_txtlogdl "Return Code:$rc\n";
    printlogdl "Return Code:$rc";
    printl "=" x 60;
    printlogl "=" x 60;
    printdl;
    if($rc == 62){
      printl "Got Invalid test cases, please exclude these cases and run again.";
      $global{RC} = $rc;
      exit_with_fail_screen($rc);
    }
    if($rc != 0 and $global{eofe} and
      not (
        $retry and $retry_type eq "SKIP" and 
        TS::Util::find_str_from_rstlog("AtcTest: MinAddress Loop count reached - Virtual address collides with other apertures")
        or
        $retry and $retry_type eq "FAIL" and
        TS::Util::find_str_from_rstlog("CRC error")
      )
    ){
      printdl "[tserver] Got error with return code $rc, about to exit.";
      printlogdl "[tserver] Got error with return code $rc, about to exit.";
      print_rstlogdl "[tserver] Got error with return code $rc, about to exit.";
      print_txtlogl "[tserver] Got error with return code $rc, about to exit.";
      $global{RC} = ($rc == -1) ? 2 : $rc;
      save_result();
      exit_with_fail_screen($rc);
    }
    
    # clear tmp files
    unlink $_ for(@config_files, $tmp_tf_name);
    save_result();
  }
  # clear global cache variables 
  @$params = ();
  @$cf = ();
  @$tf = ();
}

sub create_test_file{
  my $file = shift;
  my $tf = shift;
  printdl "Creating tf $file";
  open TMPTF, ">$file" or die "Cannot write file $file in current dir, please check your permission";
  print TMPTF (join "\n", @$tf);
  close TMPTF;
  return $file;
}

sub create_config_file{
  my $file = shift;
  my $cf = shift;
  printdl "Creating cf $file";
  die "Configuration [$cf] has not been defined yet" unless $universe->Config()->{cfs}{$cf};
  open TMPCF, ">$file" or die "Cannot write file $file in current dir, please check your permission";
  print TMPCF (join "\n", @{$universe->Config()->{cfs}{$cf}});
  close TMPCF;
  return $file;
}

sub read_tfs{
  my @tfs;
  my $tf_list = $args{tf} || "*.stf,conf/*.stf";
  for(split ',', $tf_list){
    push @tfs, glob($_);
  }
  foreach my $tf( @tfs){
    printdl "Find test file $tf";
    my @tf_action_list; # store tf action list
    my @tf_param_list; # store tf param list
    
    open IN, "<$tf" or die "Cannot open $tf to read";
    my @stack; # store block action list
    my $block = '';
    my %bconf;
    while(<IN>){
      chomp;
      s{//.*$}{};# remove // and folowing words
      s/^\s+|\s+$//g; # strip
      next if not defined $_ or $_ eq '';
      if(/#\s*BLK\s*=\s*/){ # find a block
        # clear stack and create block
        if($block){ # has block
          my $block_obj = clear_stack_and_create_block(\@stack, $block, \%bconf);
          push @tf_action_list, $block_obj;
        }else{ # doesn't have block, all previous lines are tf level action
          my ($as, $ps) = get_action_list_by_lines(\@stack);
          push @tf_action_list, @$as;
          push @tf_param_list, @$ps;
          @stack = (); # reset stack
          %bconf = (); # reset block configration
        }
        $_ =~ s/^#+//; # remove lead hash
        my $list = split_option($_);
        for(@$list){
          $bconf{$_->{name}} = $_->{value};
        }
        $block = lc(delete $bconf{BLK});
      }else{ # normal action list
        push @stack, $_;
      }
    }
    # clear stack and create block
    if($block){ # has block
      my $block_obj = clear_stack_and_create_block(\@stack, $block, \%bconf);
      push @tf_action_list, $block_obj;
    }else{ # doesn't have block
      my ($as, $ps) = get_action_list_by_lines(\@stack);
      push @tf_action_list, @$as;
      push @tf_param_list, @$ps;
      @stack = (); # reset stack
      %bconf = (); # reset block configration
    }
    close IN;
    $config->{test_files}{$tf} = new TS::TestFile(name=>$tf, actions=>\@tf_action_list, param=>\@tf_param_list); # build test file list
  }
}

sub clear_stack_and_create_block{
  my $stack = shift;
  my $block = shift;
  my $bconf = shift;

  my $block_obj = create_block_from_tf($block, $bconf, [@$stack]);
  
  @$stack = ();
  %$bconf = ();
  return $block_obj;
}

sub get_prog_count_by_queue{
  my $queue = shift;
  my $count = 0;
  foreach my $action(@$queue){
    my $class = ref $action;
    if($class eq 'TS::App'){
      $count++;
    }elsif($class eq 'TS::Block'){
      $count += get_prog_count_by_queue($action->actions);
    }elsif($class eq 'TS::TestFile'){
      $count += get_prog_count_by_queue($action->actions);
    }
  }
  return $count;
}

sub get_gopt_by_queue{
  # gopt: d tid eofe
  my $queue = shift;
  return if defined $global{d} and defined $global{tid} and defined $global{eofe} and defined $global{pr} and defined $global{log};
  foreach my $action(@$queue){
    my $class = ref $action;
    if($class eq 'TS::Case'){
      read_gopt_from_params($action->param);
    }elsif($class eq 'TS::Block'){
      my $tf = get_tf_by_block($action->name); # add tf level params
      read_gopt_from_params([@{$action->param}, @{$tf->param}]);
      get_gopt_by_queue($action->actions);
    }elsif($class eq 'TS::TestFile'){
      read_gopt_from_params($action->param);
      get_gopt_by_queue($action->actions);
    }
    last if defined $global{d} and defined $global{tid} and defined $global{eofe} and defined $global{pr} and defined $global{log};
  }
}

sub read_gopt_from_params{
  # gopt: d tid eofe pr log
  my $params = shift;
  for(@$params){
    if(/\-cf=(\S+\.cf)/){
      my $cf = $1;
      open CF, "< $cf" or die "Cannot open $cf to read\n";
      local $_;
      while(<CF>){
        # test each gopt in a row
        $global{d} = $1 if not defined $global{d} and /^\s*\-d\s*=\s*(\S+)/;
        $global{tid} = 1 if not defined $global{tid} and /^\s*\-tid/;
        $global{eofe} = 1 if not defined $global{eofe} and /^\s*\-eofe=1|^\s*\-eofe\s*$/;
        $global{eofe} = 0 if not defined $global{eofe} and /\-eofe=0/;
        $global{pr} = 1 if not defined $global{pr} and /^\s*\-pr/;
        $global{log} = 1 if not defined $global{log} and /^\s*\-log/;
        last if defined $global{d} and defined $global{tid} and defined $global{eofe} and defined $global{pr} and defined $global{log};
      }
      close CF;
    }else{
      # test each gopt in a row
      $global{d} = $1 if not defined $global{d} and /\-d=(\S+)/;
      $global{tid} = 1 if not defined $global{tid} and /\-tid/;
      $global{eofe} = 1 if not defined $global{eofe} and /\-eofe=1|\-eofe\s*$/;
      $global{eofe} = 0 if not defined $global{eofe} and /\-eofe=0/;
      $global{pr} = 1 if not defined $global{pr} and /\-pr/;
      $global{log} = 1 if not defined $global{log} and /\-log/;
    }
    last if defined $global{d} and defined $global{tid} and defined $global{eofe} and defined $global{pr} and defined $global{log};
  }
}

sub get_aspm{
  $boot_aspm  = `$tool_app -pciestatus`;
  if ($boot_aspm =~ m/ASPM = /){
    $boot_aspm =~ /ASPM = \K(\w+)/;
    $boot_aspm = $1;
    print "[tswrapper] boot_aspm = ".$boot_aspm."\n";
    return 1;
  }
  return 0;
}

sub restore_aspm{
  my $output = `$tool_app -aspm=$boot_aspm`;
    print "[tswrapper] restore aspm output = ".$output."\n";
    if($output =~ m/successful/){
    return 1;
  }
  return 0;
}

sub get_device_list{
  if(not @device_list){
    my @sdidout = `$tserver_app -skip_iommu_check -skip_consoleblank_check -d=exportdid 2>&1`;
    my @output = `$tserver_app -skip_iommu_check -skip_consoleblank_check -d=? 2>&1`;
    for my $o(@output){
      #1 PCI:0000:01:00.0 - Iceland PF
      if($o =~ /(\d+) (PCI\S+) \- (\S+) \- (\S+) \- (\S+) \- (\S+)/ and $o !~ /\bVF\b/){ # ignore VF
        my $device = {id=>$1, pci=>$2, did=>$3, rid=>$4, classid=>$5, name=>$6};
        if($o =~ /SMBUS|PSP|SDXC|ACP|AZALIA|ROOT_COMPLEX|NTBCCP|USB_MT/){
          push @device_list, {};
        }else{
          $device->{master} = 1 if $device->{classid} eq "0300";
          push @device_list, $device;
        }
      }
    }
  }
  return @device_list;
}

sub get_dgpu_device{
  if(not $dgpu_device){
    my @sdidout = `$tserver_app -skip_iommu_check -d=exportdid 2>&1`;
    my @output = `$tserver_app -skip_iommu_check -d=? 2>&1`;
    for my $o(@output){
      #1 PCI:0000:01:00.0 - Iceland PF
      if($o =~ /(\d+) (PCI\S+) \- (\S+) \- (\S+) \- (\S+) \- (\S+)/ and $o !~ /\bVF\b/){ # ignore VF
        my $device = {id=>$1, pci=>$2, did=>$3, rid=>$4, classid=>$5, name=>$6};
        if($device->{id} eq "1"){
           return "$device->{did}"
        }
      }
    }
  }
}

sub get_dgpu_revision{
  if(not $dgpu_device){
    my @sdidout = `$tserver_app -skip_iommu_check -d=exportdid 2>&1`;
    my @output = `$tserver_app -skip_iommu_check -d=? 2>&1`;
    for my $o(@output){
      #1 PCI:0000:01:00.0 - Iceland PF
      if($o =~ /(\d+) (PCI\S+) \- (\S+) \- (\S+) \- (\S+) \- (\S+)/ and $o !~ /\bVF\b/){ # ignore VF
        my $revision = {id=>$1, pci=>$2, did=>$3, rid=>$4, classid=>$5, name=>$6};
        if($revision->{id} eq "1"){
           return "$revision->{rid}"
        }
      }
    }
  }
}

sub get_dgpu_sku{
  if(not $dgpu_device){
    my @sdidout = `$tserver_app -skip_iommu_check -d=exportdid 2>&1`;
    my @output = `$tserver_app -skip_iommu_check -d=? 2>&1`;
    for my $o(@output){
      #1 PCI:0000:01:00.0 - Iceland PF
      if($o =~ /(\d+) (PCI\S+) \- (\S+) \- (\S+) \- (\S+) \- (\S+\s\S+) \- (\S+)/ and $o !~ /\bVF\b/){ # ignore VF
        my $sku = {id=>$1, pci=>$2, did=>$3, rid=>$4, classid=>$5, name=>$6, sku=>$7};
        if($sku->{id} eq "1"){
           return "$sku->{sku}"
        }
      }
    }
  }
}


sub get_master_device_opt{
  my @d = get_device_list();
  foreach my $d(@d){
    if($d and %$d and $d->{id} and $d->{master}){
      return "-d=$d->{id}";
    }
  }
  return "";
}

sub get_device_sku{
  if(not @device_sku){
    my $cmd = $TS::AppConf::is_win ? "amdvbflash.exe -i" : "./amdvbflash -i";
    my $output = `$cmd`;
    while($output =~ /\s\d+\-(\w+)\-[\d\w]+\s/g){
      push @device_sku, $1;
    }
  }
  return @device_sku;
}

sub is_SSG_sku{
	my @device_sku = get_device_sku();
	my $count = 0;
	foreach my $key(@SSG_sku){
		$count = 0;
		for(@device_sku){
			$count++ if /^$key/;
		}
		return 1 if $count==1;
	}
	return 0;
}

sub is_PCIE_sku{
	my @device_sku = get_device_sku();
	my $count = 0;
	foreach my $key(@pcie_sku){
		$count = 0;
		for(@device_sku){
			$count++ if /^$key/;
		}
		return 1 if $count==1;
	}
	return 0;
}

sub is_pro_sku{
	my @device_sku = get_device_sku();
	my $count = 0;
	foreach my $key(@pro_sku){
		$count = 0;
		for(@device_sku){
			$count++ if /^$key/;
		}
		return 1 if $count==2;
	}
	return 0;
}

sub is_nobaco_sku{
  my $sku = get_dgpu_sku();
  foreach my $no_baco_sku(@no_baco_sku){
    if ($sku eq $no_baco_sku){
      return 1;
    }
  }
  return 0;
}

sub is_nobamaco_sku{
  my $sku = get_dgpu_sku();
  foreach my $no_bamaco_sku(@no_bamaco_sku){
    if ($sku eq $no_bamaco_sku){
      return 1;
    }
  }
  return 0;
}



sub is_gemini_sku{
  my @device_sku = get_device_sku();
  my $count = 0;
  foreach my $key(@gemini_sku){
    $count = 0;
    for(@device_sku){
      $count++ if /^$key/;
    }
    return 1 if $count==2;
  }
  return 0;
}

sub run_os_spec{
  my $options = shift;
  if($TS::AppConf::os eq "win" and ($args{test} || $args{block} || $args{seqfile} || $args{tf} || $args{func} || $args{boardtest} || $args{slttest}) and not ($args{dryrun} || $args{tclist})){
    my $cmd = "cscript.exe tserver.vbs $options";
    print "$cmd\n";
    system("cscript.exe tserver.vbs $options");
  }
}

sub loop_count_start{
  $scriptloop_start_time = time;
}

sub loop_count_stop{
  my $curr_loop_time = time-$scriptloop_start_time;
  my $print_string = "Loop ".$loop_count." Execution Time: ".second_2_read(time-$scriptloop_start_time);
  my $percentage = $args{loopdiff} / 100; 
  
  printl  $print_string;
  print_txtlogl $print_string;
 
  if ($loop_count > 1) {
    if ($curr_loop_time > ($prev_loop_time * ($percentage + 1)) || $curr_loop_time < ($prev_loop_time - ($prev_loop_time * $percentage))){
      printl "Warning: Loop $loop_count execution time anomaly detected";
      print_txtlogl "Warning: Loop $loop_count execution time anomaly detected";
    }
  }

  $prev_loop_time = $curr_loop_time;
  $loop_count++;
}

####################
# generic functions
####################
# log manage
####################
sub open_export_file{
  return unless defined $args{export};
  my $logfile = $config->{log}{export};
  open LOGFILE, ">$logfile" or die "Cannot open $logfile to write";  
}
sub close_export_file{
  return unless defined $args{export};
  close LOGFILE;
}

######################
# print functions
######################
sub printlog{
  print LOGFILE @_ if defined $args{export};
}

sub printlogl{
  printlog(@_,"\n");
}

sub printlogd{
  printlog(@_) if $args{debug};
}

sub printlogdl{
  printlog(@_, "\n") if $args{debug};
}

sub print_txtlog{
  my @prefix = ("<".SimpleTime::time_2_str(time, '%H:%M:%S')."> <common> <Wrapper>: ");
  write_to_file_add("log.txt", @prefix, @_) if $args{log};
}

sub print_txtlogl{
  print_txtlog(@_, "\n");
}

sub print_txtlogd{
  print_txtlog(@_) if $args{debug};
}

sub print_txtlogdl{
  print_txtlogl(@_) if $args{debug};
}

sub print_rstlog{
  # if -tid or -log
  my $file = "testid.log";
  if($global{tid}){
    write_to_file_add($file, @_); 
  }
  #return unless $universe->Config->{log}{type} eq "text";
  #write_to_file_add($universe->Config->{log}{file}, @_);
}

sub print_rstlogl{
  print_rstlog(@_, "\n");
}

sub print_rstlogd{
  print_rstlog(@_) if $args{debug};
}

sub print_rstlogdl{
  print_rstlogl(@_) if $args{debug};
}

sub backup_rstlog{
  return unless -e $universe->Config->{log}{file};
  my $newfile = $universe->Config->{log}{file}.".".time.".".int(rand(1000));
  rename $universe->Config->{log}{file}, $newfile;
  return $newfile;
}

sub remove_rstlog{
  return unless -e $universe->Config->{log}{file};
  unlink $universe->Config->{log}{file};
}

sub recover_rstlog{
  my $oldfile = shift;
  return unless $oldfile and -e $oldfile;
  rename $oldfile, $universe->Config->{log}{file} or die "$@";
}

sub append_file_to_rstlog{
  my $file = shift;
  return unless $file and -e $file;
  open IN, "<", $file or die "Cannot open $file to read $@";
  open OUT, ">>", $universe->Config->{log}{file} or die "Cannot open $file to write $@";
  while(<IN>){
    print OUT $_;
  }  
  close OUT;
  close IN;
}

sub get_last_result_from_rstlog{
  my $status = "";
  if(not $args{dryrun}){
    my $result = TS::Util::read_last_log();
    if( $result and %$result and $result->{tests}){
      $status = $result->{tests}[-1]{test}{result};
    }
  }
  return $status;
}

sub backup_tidchecklist{
         my $oldfile = "testid.log";
         my $newfile = "checklist";
         copy( $oldfile, $newfile ) or die "Copy failed: $!";
         return $newfile;
 }


sub CheckArgs{
  my $errstr = "";
  if($args{boardtest}){
    $errstr .= "Option $args{boardtest} was not defined for parameter boardtest" unless exists $universe->Config()->{params}{boardtest} and exists $universe->Config()->{params}{boardtest}{options}{$args{boardtest}};
  }
  if($args{expand}){
    $errstr .= "Option $args{expand} can not be supported by $tserver_app" unless support_tclist_option();
    $errstr .= "expand option shall used with -showtest" unless defined $args{showtest};
  }
  if($args{filter}){
    $errstr .= "Option cannot be supported, which need $tserver_app support 'tclist'\n" unless support_tclist_option();
    $errstr .= "filter need to define STF or block to run" unless defined $args{tf} or defined $args{block};
  }
  if(exists $args{suitemargin}){
    if($args{suitemargin} =~  /(\-?[\w\.]+\%?),(\-?[\w\.]+\%)(\,(0x\w+))?/){
      $config->{suitemargin}{eng_inc} = $1;
      $config->{suitemargin}{mem_inc} = $2;
      $config->{suitemargin}{vddc_inc} = $4||0;
    }else{
      $errstr .= "Invalid option suitemargin\n";
    }
  }
  if(exists $args{edcsort}){
    my @edc = split ",", $args{edcsort};
    if(@edc == 4){
      $config->{edcsort}{edc_vddc_inc} = $edc[0];
      $config->{edcsort}{edc_vddci_inc} = $edc[1];
      $config->{edcsort}{edc_sclk_inc} = $edc[2];
      $config->{edcsort}{edc_mclk_inc} = $edc[3];
    }else{
      $errstr .= "Invalid option edcsort";
    }
  }

  if(exists $args{extsort}){
    my @ext = split ",", $args{extsort};
    if((@ext == 2) && ($ext[0]=~/['0','1']/) && ($ext[1]=~/['0','1']/)){
      $config->{extsort}{ext_edcfa} = $ext[0];
      $config->{extsort}{ext_vddc_check} = $ext[1];
    }else{
      $errstr .= "Invalid option extsort";
    }
  }
  if(exists $args{defstate}){
    my @state = split ",", $args{defstate};
    if(@state >= 2){
      $config->{defstate}{mode} = $state[0];
      $config->{defstate}{sclk_dpm_state} = $state[1];
      $config->{defstate}{mclk_dpm_state} = defined $state[2] ?  $state[2] : $state[1];
    }else{
      $errstr .= "Invalid option defstate\n";
    }
  }

  if(exists $args{mcchannel}){
      my @channel = split ",", $args{mcchannel};
      if(@channel == 1){
          $config->{mcchannel}{channel} = $channel[0];
      }else{
          $errstr .= "Invalid option mcchannel\n";
      }
  }

  if($errstr){
    printl $errstr, "\n";
    Usage(); 
    exit 2;
  }
  unless(%args){ # print out help page if no option specified
    Usage(); 
    exit 0;
  }

  for(qw/tid d eofe log/){
    $global{$_} = $args{$_} if exists $args{$_};
  }
}

sub Usage{
  use File::Basename;
  my $dir = dirname $0;
  my $bin = "tserver"; 
  if($dir eq "." or not $dir){
    $bin = $TS::AppConf::is_win ? "tserver.exe" : "./tserver";
  }else{
    $bin = $TS::AppConf::is_win ? "$dir\\tserver.exe" : "$dir/tserver";
  }
  print <<EOF;
Usage: $bin [OPTION]...
Run a set of Diagnostics test sequence specified by options

Argumeuts or options:
  -blk|block=BLK[,BLK]...	run predefined block BLK
  -tf=STF		run predefined test file STF
  -test=TEST   		run single test TEST
  -seqfile=filename     run predefined sequece file(.pl)
			[-test, -block, -tf, -seqfile are exclusive options]

  -sl|scriptloop=NUM	run sequence NUM times
  -eofe			exit on first error
  -defstate=mode,state	define default state
  -nosetstate           disable set state
  -suitemargin=eng_inc,mem_inc[,vddc_inc]  define default suitemargin
  -nogb			disable guard band
  -noctf		ignore ctf related tests
  -nobaco               ignore baco related tests
  -export		export system call commands to tserver.log
  -clearlog		clear testid.log|log.yml before any test
  -rmdriver		unload driver and remove any existent amddiag modules, forcing reinstall
  -dryrun		run test flow without execution of tserverlite and cmd
  -tclist               list test cases about to run, wildcards will be expanded
  -showblock[=STF]	show block list, show block list in STF if STF was specified
  -showtest[=STF]	show test list, show test list in STF if STF was specified
  -showtest[=STF] -expand  
             show test list in an STF or BLK, the test list will be expanded with -expand option.  
             [usag:-tf=STF|-blk=BLK -showtest -expand or -showtest=STF -expand]
  -filter=blk:BLK,test:TEST 
             when run a STF or BLK , add filter will only run the specified test
             in the STF or BLK
             [usage:-tf=STF -filter=blk:BLK,test:TEST|-blk=BLK -filter=test:TEST]
  -v,     --verbose     open verbose flag
  -h,     --help        show this page
EOF
  if(defined &{"main::SuiteUsage"}){ #print out suite level help page
    &main::SuiteUsage();
  }
}

sub END{
  # run myreport
  if($args{report}){
#    printl "$args{report}";
    system($args{report}); # the report script is not part of tserver, ignore return code
  }

  my $tmp_rstlog = backup_rstlog();
  recover_rstlog($global{old_logyml});
  append_file_to_rstlog($tmp_rstlog);
  unlink $tmp_rstlog;
#  always keep log.yml
#  unlink $universe->Config->{log}{file} unless($global{tid} or $global{log}); 
  unlink "testid.log" unless $global{tid} or $args{report};
#  always keep log.txt (manage log.txt in suite_xx.pl)
#  unlink "log.txt" unless $global{log};
  $global{RC} = ($? == 0 ? $global{RC} : $? );
  exit $global{RC};
}
