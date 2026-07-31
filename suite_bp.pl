#!/usr/bin/perl
use strict;
our %args;
use subs qw/
    quickmfg quickmfg4 qualmfg qualmfg4 extmfg config memfa memfa2 dpm ctf mfgfa
    init info NAVI23_MEMFA navi23_stress soft_reset enable_umcch_power_gating
    disable_umcch_power_gating enable_dyn_disconnect enable_smc_fan_control
    disable_smc_fan_control dpm_sequence fan memfa2 init_flow deinit_flow
    bump_clocks restore_nature_dpm set_mclk_dpm sku_detect register_param_option
    register_param_default add_prog add_tool add_sub add_block add_func_param
    clear_func_param set_env_opt bp_sequence bq_sequence fa2_sequence
    thermaltune_sequence extmfg_menu printl save_cfgdata read_input
 /;
our $tsl_param;
our %global;
our $smbus_address;
our $enable_vcn;
our $dgpu_did;
our $dgpu_rid;
our $sku = get_dgpu_sku();
our @no_baco_sku = ("XM","XMW","GLXTA");
our @no_bamaco_sku = ("XM","XMW","GLXTA","XL");
our $no_baco_sku = is_nobaco_sku();
our $no_bamaco_sku = is_nobamaco_sku();

$dgpu_did=get_dgpu_device();
$dgpu_rid=get_dgpu_revision();


register_param_option(
  boardtest => [qw/
    quickmfg quickmfg4 qualmfg qualmfg4 extmfg memfa memfa2 dpm config ctf mfgfa info init chkfp NAVI23_MEMFA navi23_stress navi23_channels/],
);

# config: quickmfg dpm ctf pcie-linkwidth
register_param_default(boardtest=>"quickmfg");

sub soft_reset {
    add_prog "./db32 cmd 'select_did $dgpu_did;exe cp_reset.db32'";
}

sub enable_umcch_power_gating {
    add_prog "./db32 cmd 'select_did $dgpu_did;exe epg.db32'";
}

sub disable_umcch_power_gating {
    add_prog "./db32 cmd 'select_did $dgpu_did;exe dpg.db32'";
}

sub enable_dyn_disconnect {
    add_prog "./db32 cmd 'select_did $dgpu_did;exe dyn.db32'";
}

sub quickmfg {
    info();
    init_flow(1);
    add_sub(sub{set_env_opt("setstate"=>1, gb=>0, mba=>0)});
    bp_sequence("3");
    add_sub(sub{set_env_opt("setstate"=>0, gb=>0, mba=>0)});
    # deinit_flow() already in the sub
}

sub quickmfg4 {
    info();
    init_flow(1);
    add_sub(sub{set_env_opt("setstate"=>1, gb=>0, mba=>0)});
    bp_sequence("4");
    add_sub(sub{set_env_opt("setstate"=>0, gb=>0, mba=>0)});
    # deinit_flow() already in the sub
}

sub qualmfg {
    info();
    init_flow(1);
    add_sub(sub{set_env_opt("setstate"=>1, gb=>0, mba=>0)});
    bp_sequence("3");
    init_flow(1);
    bq_sequence();
    add_sub(sub{set_env_opt("setstate"=>0, gb=>0, mba=>0)});
    # deinit_flow() already in the sub
}

sub qualmfg4 {
    info();
    init_flow(1);
    add_sub(sub{set_env_opt("setstate"=>1, gb=>0, mba=>0)});
    bp_sequence("4");
    init_flow(1);
    bq_sequence();
    add_sub(sub{set_env_opt("setstate"=>0, gb=>0, mba=>0)});
    # deinit_flow() already in the sub
}

sub dpm {
    info();
    init_flow(0);
    add_sub(sub{set_env_opt("setstate"=>1, gb=>0, mba=>0)});
    dpm_sequence();
    add_sub(sub{set_env_opt("setstate"=>0, gb=>0, mba=>0)});
    deinit_flow();
}

sub mfgfa {
    info();
    init_flow(1);
    add_sub(sub{set_env_opt("setstate"=>1, gb=>0, mba=>0)});
    fa2_sequence("3");
    add_sub(sub{set_env_opt("setstate"=>0, gb=>0, mba=>0)});
    deinit_flow();
}

sub chkfp {
    info();
    init_flow(0);
    add_sub(sub{set_env_opt("setstate"=>1, gb=>0, mba=>0)});
    chkfp_sequence();
    add_sub(sub{set_env_opt("setstate"=>0, gb=>0, mba=>0)});
    deinit_flow();
}

sub thermaltune {
    info();
    sku_detect();
    init_flow(0);
    add_sub(sub{set_env_opt("setstate"=>1, gb=>0, mba=>0)});
    thermaltune_sequence("3");
    add_sub(sub{set_env_opt("setstate"=>0, gb=>0, mba=>0)});
    deinit_flow();
}

sub thermaltune4 {
    info();
    sku_detect();
    init_flow(0);
    add_sub(sub{set_env_opt("setstate"=>1, gb=>0, mba=>0)});
    thermaltune_sequence("4");
    add_sub(sub{set_env_opt("setstate"=>0, gb=>0, mba=>0)});
    deinit_flow();
}

sub print_and_log {
    my $string = shift || "";
    print $string;
    if (-e 'log.txt') {
       write_to_file_add("log.txt", $string);
    } else {
       write_to_file("log.txt", $string);
    }
}

sub info {
    print_and_log("\n\n================================= INFO ========================================\n");
    print "\nWelcome to the Diagnostics Board Production Suite\n\n";
    print "Build and System Info:\n";
    my @temp = %args;
    my $speed = shift || 4;
    my $flow = shift || "general";
    #Variables for the requirement of date, present working diretory and
    my $hostname_string = `hostname`;
    my $prewrkdir_string = `pwd`;
    my $date_var_string = `date`;

    #Code to print the date, present working directory and the hostname.
    print_and_log("Hostname: "."$hostname_string");
    print_and_log("Present Working Directory: "."$prewrkdir_string");
    print_and_log("Date: "."$date_var_string");
    #Log Release package info
    print_and_log("Release Package Info: ");
    my @tarballs = glob("*.tar.gz");
    if (@tarballs){
       foreach my $tarball (@tarballs){
          print_and_log("\n    $tarball");
       }
    } else {
       print_and_log("No tar.gz files found");
    }
    #Log commandline args and testflow
    print_and_log("\nPCIe Speed: $speed");
    print_and_log("\nTestflow: $flow\n");
    print_and_log ("Commandline Arguments:\n\t@temp\n");

    #Log Tserverlite version info
    print_and_log("\nTserverlite Version Info:");
    my $tserverlite_string = `./tserverlite 2>&1`;
    my @tserverlite_string_lines = split("\n", $tserverlite_string);
    foreach my $tserverlite_string_line (@tserverlite_string_lines){
       if (($tserverlite_string_line =~ m/Project/) or ($tserverlite_string_line =~ m/Build date/) or ($tserverlite_string_line =~ m/Version/) or ($tserverlite_string_line =~ m/Suite/)) {
          print_and_log("\n    $tserverlite_string_line");
       }
    }

    #Log vbios and GPU Info
    print_and_log("\n\nVBIOS and GPU Info: ");
    if (-e 'amdvbflash'){
       my $vbios_string = `./amdvbflash -ai`;
       if ($vbios_string =~ m/Product Name/){
          my @vbios_string_lines = split("\n", $vbios_string);
          my @vbios_string_lines = split("\n", $vbios_string);
          foreach my $vbios_string_line (@vbios_string_lines){
             if (($vbios_string_line =~ m/AMDVBFLASH/) or ($vbios_string_line =~ m/Product Name/) or ($vbios_string_line =~ m/Bios P/) or ($vbios_string_line =~ m/Bios Version/) or ($vbios_string_line =~ m/Bios Date/)) {
                 print_and_log("\n$vbios_string_line");
             }
          }
          print_and_log("\n");
          } else {
          print_and_log("Unable to read vbios and GPU info.\n");
       }
    } else {
       print_and_log("amdvbflash utility not found.\n");
    }

    #VBIOS Build Number
    print_and_log("\nVBIOS Build Number: ");
    my $vbios_build_number_string = `./agt -biosbuildnum`;
    my @vbios_build_number_string_lines = split("\n", $vbios_build_number_string);
    foreach my $vbios_build_number_string_line (@vbios_build_number_string_lines){
       if ($vbios_build_number_string_line =~ m/Number/) {
          print_and_log("\n    $vbios_build_number_string_line\n");
       }
    }

    #Serial ID
    print_and_log("\nSID Info: ");
    my $sid_string = `./agt -sid`;
    my @sid_string_lines = split("\n", $sid_string);
    foreach my $sid_string_line (@sid_string_lines){
       if (($sid_string_line =~ m/agt/) or ($sid_string_line =~ m/SerialID/) or ($sid_string_line =~ m/Leakage/) or ($sid_string_line =~ m/DeviceID/) or ($sid_string_line =~ m/Raw_ID/)) {
          print_and_log("\n    $sid_string_line");
       }
    }

    print_and_log("\n================================================================================\n\n\n");
}

sub init {
    info();
    init_flow(1);
    print "Initialization complete.";
}

# Set PPMode to Perf and load PPTable
sub init_flow {
    $enable_vcn = shift;
    # First load TOS + SMU FW
    add_tool("-loadmeucode");
    clear_func_param;
    add_func_param("-cf=tserver-init.cf");
    add_block "INIT";
    add_tool("-ppmode=1");
    add_block "INIT_1";
    if($enable_vcn)
    {
        add_block "VCN_POWER_UP";
    }
}

sub deinit_flow {
    if($enable_vcn)
    {
        clear_func_param;
        add_func_param("-cf=tserver.cf");
        add_block "VCN_POWER_DOWN";
        $enable_vcn = 0;
    }
}

sub bump_clocks {
    if($enable_vcn)
    {
        add_tool("-ppdpmforce=VCN,max");
    }
    add_tool("-ppdpmforce=SOC,max");
    add_tool("-ppdpmforce=MCLK,max");
}

sub restore_nature_dpm {
    if($enable_vcn)
    {
        add_tool("-ppdpmrestore=VCN");
    }
    add_tool("-ppdpmrestore=SOC");
    add_tool("-ppdpmrestore=MCLK");
}

sub set_mclk_dpm {
    add_tool("-ppdpmstatus=mclk,off");
    add_tool("-ppdpmstatus=mclk,on");
}

sub disable_smc_fan_control {
    clear_func_param;
    add_func_param("-cf=tserver-fan.cf");
    add_block "FAN_CTRL_DISABLE";
    add_prog("./db32 cmd regw32 0x05999c 0x7d");
}

sub enable_smc_fan_control {
    clear_func_param;
    add_func_param("-cf=tserver-fan.cf");
    add_block "FAN_CTRL_ENABLE";
}

sub dpm_sequence {
    set_mclk_dpm();
    clear_func_param;
    add_func_param("-cf=tserver.cf");
    soft_reset();
    # AutoDPMToggle GFX and UMC Tests
    add_block "AUTO_DPM_TOG";
    add_block "AUTO_DPM_TOG_GFX_UMC";
}

sub fan {
    deinit_flow();
    baco();
    add_tool("-loadmeucode");
    clear_func_param;
    add_func_param("-cf=tserver-fan.cf");
    add_block "FAN";
    clear_func_param;
    add_func_param("-cf=tserver-init.cf");
    add_block "INIT";
    add_tool("-ppmode=1");
    add_block "VCN_POWER_UP";
    $enable_vcn=1;
    clear_func_param;
}

sub memfa {
    info();
    init_flow(1);
    bump_clocks();
    clear_func_param;
    add_func_param("-cf=tserver.cf");
    add_block "Memfa-Basic";
    add_block "Memfa-RandomBlt";
    restore_nature_dpm();
    clear_func_param;
    add_func_param("-cf=tserver.cf");
    add_block "Memfa-Basic";

    bump_clocks();
    clear_func_param;
    add_func_param("-cf=tserver.cf");
    add_block "Memfa-umc";
    restore_nature_dpm();
    clear_func_param;
    add_func_param("-cf=tserver.cf");
    add_block "Memfa-umc";
}

sub NAVI23_MEMFA {
    info();
    init_flow(1);
    bump_clocks();
    clear_func_param;
    add_func_param("-cf=tserver-navi23.cf");
    add_block "navi23_memfa";
    restore_nature_dpm();
}

sub navi23_stress {
    info();
    init_flow(1);
    bump_clocks();
    clear_func_param;
    add_func_param("-cf=tserver-navi23.cf");
    add_block "navi23_stress";
    restore_nature_dpm();
}

sub navi23_channels {
    info();
    init_flow(1);
    bump_clocks();
    clear_func_param;
    add_func_param("-cf=tserver-navi23.cf");
    add_block "NAVI23_CHANNELS";
    restore_nature_dpm();
}

sub memfa2 {
    info();
    init_flow(0);
    restore_nature_dpm();
    clear_func_param;
    add_func_param("-cf=tserver.cf");
    add_block "Memory";
    add_block "UMC_LFB";
    add_block "UMC_STD";
    add_block "Stress3D_WITH_NATURE_DPM";
    
    add_block "PM4Player";

    bump_clocks();
    add_block "VCN_POWER_UP";
    add_block "Memory";
    add_block "UMC_LFB";
    add_block "UMC_STD";
    add_block "Stress3D_Memfa2";
    
    add_block "PM4Player";
    
    add_block "Memfa-Basic";
    add_block "VCN_POWER_DOWN";
    restore_nature_dpm();
}


sub config {
    my $input = extmfg_menu();

    printl "Are you going to run the tests?";
    printl extmfg_hcfg($input);
   
    save_cfgdata($input);

    exit 0 unless read_input("Selection (Y/N)[Y]: ", [qw/Y N/], 'Y') eq 'Y';  

    extmfg();   
}

sub extmfg_menu {
    my %input;

    $input{err_pause} = read_input("Choose error reporting method:
E :: Exit without pause on error
P :: Exit with pause on error
C :: Continue without pause on error
W :: Continue with pause on error
Selection: [E] ", [qw/E P C W/], 'E', {E=>{pause=>0, to_exit=>1}, P=>{pause=>1, to_exit=>1}, C=>{pause=>0, to_exit=>0}, W=>{pause=>1, to_exit=>0}});
    $input{stutter} = read_input("Run Stutter mode tests?\nSelection (Y/N)[Y]: ", [qw/Y N/], 'Y', {Y=>1, N=>0});
    $input{umcpg} = read_input("Run UMC Power Gating tests?\nSelection (Y/N)[Y]: ", [qw/Y N/], 'Y', {Y=>1, N=>0});
    $input{dpm} = read_input("Run DPM board manufacturing test?\nSelection (Y/N)[Y]: ", [qw/Y N/],'Y', {Y=>1, N=>0});
    $input{pcie} = read_input("Run PCIE Tests?\nSelection (Y/N)[Y]: ", [qw/Y N/], 'Y', {Y=>1, N=>0});
    $input{pcie_link_width} = read_input("Configure PCIE Link Width tests?\nSelection (Y/N): [Y] ", [qw/Y N/], 'Y', {Y=>1, N=>0}) if $input{pcie};
    $input{gen_mfg} = read_input("Run General tests?\nSelection (Y/N)[Y]: ", [qw/Y N/], 'Y', {Y=>1, N=>0});
    $input{gfx} = read_input("Run GFX tests?\nSelection (Y/N)[Y]: ", [qw/Y N/],'Y', {Y=>1, N=>0});
    $input{vcn} = read_input("Run VCN tests?\nSelection (Y/N)[Y]: ", [qw/Y N/], 'Y', {Y=>1, N=>0});
    $input{gfxoff} = read_input("Run GFXOFF tests?\nSelection (Y/N)[Y]: ", [qw/Y N/], 'Y', {Y=>1, N=>0});
    $input{fan} = read_input("Run Fan test?\nSelection (Y/N)[N]: ", [qw/Y N/], 'N', {Y=>1, N=>0});
    #$input{smbus_gpu} = read_input("Run SMBUS_GPU test?\nSelection (Y/N)[N]: ", [qw/Y N/], 'N', {Y=>1, N=>0});
    #$input{smbus_board} = read_input("Run External Thermal controller LM96163 test?\nSelection (Y/N)[N]: ", [qw/Y N/], 'N', {Y=>1, N=>0});
    #$input{usb} = read_input("Run USB test?\nSelection (Y/N)[N]: ", [qw/Y N/], 'N', {Y=>1, N=>0});
    $input{zero_rpm} = read_input("Run ZERO RPM test?\nSelection (Y/N)[N]: ", [qw/Y N/], 'N', {Y=>1, N=>0});
    $input{baco} = read_input("Run BACO test?\nSelection (Y/N)[Y]: ", [qw/Y N/], 'Y', {Y=>1, N=>0});
    $input{bamaco} = read_input("Run BAMACO test?\nSelection (Y/N)[N]: ", [qw/Y N/], 'N', {Y=>1, N=>0});

    #Get PCIE link speed for all tests that need it
    if ($input{pcie} or $input{pcie_link_width} or $input{gen_mfg}) {
        $input{pcie_gen} = read_input("Select PCIE generation the board supports:
3 :: Gen3
4 :: Gen4
Selection: [3]: ", [qw/3 4/], '3');
    }

    #Get PCIE link width for all tests that need it
    if ($input{pcie_link_width}) {
        $input{pcie_width_X} = read_input("Select the PCIE link width parameter that the board upto support:
X4 :: run PCIE link width tests based on link width x4
X8 :: run PCIE link width tests based on link width x8
Selection: [X8] ", [qw/X4 X8/], "X8");
    }
    $input{ctf} = read_input("Run CTF test?\nSelection (Y/N)[N]: ", [qw/Y N/], 'N', {Y=>1, N=>0});
#    if ($input{ctf}) {
#        $input{ctf_type} = read_input("Select CTF type:
#1 :: GPU CTF
#2 :: LCS CTF
#Selection: [1] ", [qw/1 2/], '1');
    $input{enable_vcn} = 0;
    if($input{vcn})
    {
        $input{enable_vcn} = 1;
    }

    return \%input;
}

sub extmfg_hcfg {
    my $input = shift;
    my %input = %$input;
    my $hcfg = "";
    $hcfg .= "\t".($input{err_pause}{to_exit} ? "Exit" : "Continue")." ".($input{err_pause}{pause} ? "with" : "without")." pause on error\n" if $input{err_pause};
    $hcfg .= "\tStutter Mode Tests\n" if $input{stutter};
    $hcfg .= "\tUMC Power Gating Tests\n" if $input{stutter};
    $hcfg .= "\tDPM Tests\n" if $input{dpm};
    $hcfg .= "\tPCIE Gen".$input{"pcie-gen"}." Tests\n" if $input{pcie};
    $hcfg .= "\tPCIE link width Tests\n" if $input{pcie_width_X};
    $hcfg .= "\tGeneral Tests\n" if $input{gen_mfg};
    $hcfg .= "\tGFX tests\n" if $input{gfx};
    $hcfg .= "\tVCN Tests\n" if $input{vcn};
    $hcfg .= "\tGFXOFF Tests\n" if $input{gfxoff};
    $hcfg .= "\tFan Tests\n" if $input{fan};
    #$hcfg .= "\tSMBUS_LM96163_ADM1032_EMC2103 Tests\n" if $input{smbus_board};
    #$hcfg .= "\tSMBUS_GPU\n" if $input{smbus_gpu};
    #$hcfg .= "\tThermal External Tests\n" if $input{thermal_external};
    #$hcfg .= "\tUSB Tests\n" if $input{usb};
    $hcfg .= "\tZERO RPM Tests\n" if $input{zero_rpm};
    $hcfg .= "\tBACO Tests\n" if $input{baco};
    $hcfg .= "\tBAMACO Tests\n" if $input{bamaco};
    $hcfg .= "\tGPU CTF Tests\n" if ($input{ctf});
    #$hcfg .= "\tGPU CTF Tests\n" if ($input{ctf} && $input{gpu_ctf} == "1");
    #$hcfg .= "\tLCS CTF Tests\n" if ($input{ctf} && $input{gpu_ctf} == "0");

    return $hcfg;
}

sub extmfg {
    my $cfg = read_cfgdata();

    if ($cfg and %$cfg) {
        my %input = %$cfg;
        info();
	printl "Going to run test with configuration:";
        printl extmfg_hcfg($cfg);

        if ($input{err_pause}) {
            $input{err_pause}{pause} ||= 0;
            $global{"s"} = $input{err_pause}{pause};
            $tsl_param .= " -s=" . $input{err_pause}{pause};
            if ($input{err_pause}{to_exit}) {
                $tsl_param .= " -eofe";
                $global{eofe} = 1;
            } else {
                $tsl_param .= " -eofe=0";
                $global{eofe} = 0;
            }
        }

        if ($input{smbus_address}) {
            $smbus_address = $input{smbus_address};
        }

        add_sub(sub{set_env_opt("setstate"=>1)});
        add_sub(sub{set_env_opt("gb"=>1)}) if $input{gb};


        init_flow($input{enable_vcn});

	stutter() if $input{stutter};
        umcpg() if $input{umcpg};
	dpm_sequence() if $input{dpm};
        pcie($input{pcie_gen}) if $input{pcie};
        pcie_link_width($input{pcie_width_X},$input{pcie_gen}) if $input{pcie_width_X};
        gen_mfg($input{pcie_gen}) if $input{gen_mfg};
        gfx() if $input{gfx}; 
        vcn() if $input{vcn};
	gfxoff() if $input{gfxoff};
	smbus_board() if $input{smbus_board};
        smbus_gpu() if $input{smbus_gpu};
        thermal_external() if $input{thermal_external};
	usb($input{"usb"}) if $input{"usb"};
        zero_rpm($input{"zero_rpm"}) if $input{"zero_rpm"};
        remote_management() if $input{"remote_management"};
        fan() if $input{fan};
        if ($input{bamaco}) {
            deinit_flow();
            bamaco();
            init_flow(1);
        }
        if ($input{baco}) {
            deinit_flow();
            baco();
            init_flow(1);
        }

        if ($input{"ctf"} == "1") {
	    #if ($input{"gpu_ctf"} == "1") {
                gpu_ctf();
            #}
	    #else {
	    #        lcs_ctf();
	    #}
        }

        deinit_flow();
    } else {
        print "Board test hasn't been configured yet, going to config\n";
        config();
    }
}

sub pcie_link_width {
    my $width = shift;
    my $speed = shift || 3;

    add_tool "-ppdpmstatus=PCIE,off";
    clear_func_param;
    add_func_param("-cf=tserver.cf");
    add_sub(sub{get_aspm()});
    add_tool "-aspm=off";

    soft_reset();
    if ($speed == 3) {
	add_tool "-pcielinkspeed=3";
    }
    if ($speed == 4) {
	add_tool "-pcielinkspeed=4";
    } 
    add_block "PCIE_Link_Width_".$width."_Test";
    add_sub(sub{restore_aspm()});
    add_tool "-ppdpmstatus=PCIE,on";
}

sub pcie {
    my $speed = shift || 3;

    clear_func_param;
    add_func_param("-cf=tserver.cf");
    add_tool "-ppdpmstatus=PCIE,off";
    add_sub(sub{get_aspm()});
    add_tool "-aspm=off";

    soft_reset();
    if ($speed == 3) {
        if ($TS::AppConf::is_amd){
             add_block "PCIE_PHY_test_Gen3_prepare";
        }
	add_tool "-pcielinkspeed=3";
        add_block "PCIE_Link_Width_Speed_Test";
        add_block "PCIE_Link_Quality_Test";
        add_block "PCIE_Link_Width_X8_Test";
    }
    if ($speed == 4) {
        if ($TS::AppConf::is_amd){
            add_block "PCIE_PHY_test_Gen4_prepare";
        }
        add_tool "-pcielinkspeed=4";
        add_block "PCIE_Link_Width_Speed_Test_Gen4";
        add_block "PCIE_Link_Quality_Test_Gen4";
        add_block "PCIE_Link_Width_X8_Test";
    } 
    add_sub(sub{restore_aspm()});
    add_tool "-ppdpmstatus=PCIE,on";
}

sub gen_mfg {
    my $speed = shift || 3;

    # PCIe Tests
    pcie($speed);

    clear_func_param;
    add_func_param("-cf=tserver.cf");

    # DF Tests
    add_block "DF_Atomics_test_0";
    add_block "DF_Atomics_test_1";
    add_block "DF_Coherency_test";

    # OSS Tests
    add_block "OSS_SDMA_Linear";
    add_block "OSS_SDMA";

    # Memory Tests
    add_block "Memory";
    add_block "UMC_LFB";
    add_block "UMC_STD";

    # MHUBs Tests
    add_block "MHUB";
}


sub bp_sequence {
    my $speed = shift || 3;
    add_tool "-pcielinkspeed=$speed";
    print "Current PCIe speed: Gen$speed\n";

    stutter();
    umcpg();
    dpm_sequence();
    gen_mfg($speed);
    gfx();
    vcn();
    gfxoff();
    if ($args{usb}) {
        usb();
    }
    
    deinit_flow();

    if (!$args{nobamaco} and !$args{nobaco}) {
        bamaco();
        init_flow(0); 
    }

    if (!$args{nobaco}) {
        baco();
    }

    init_flow();

    gpu_ctf();

    deinit_flow();
}

sub bq_sequence {
    bump_clocks();

    disable_smc_fan_control();

    soft_reset();
    clear_func_param;
    add_func_param("-cf=tserver-bq.cf");
    add_block "BQ_Memory";

    enable_smc_fan_control();

    clear_func_param;
    add_func_param("-cf=tserver-bq.cf");
    
    add_block "BQ_Multi_SDMA";
    add_block "BQ_Multi_WITH_NATURE_DPM";

    clear_func_param;
    add_func_param("-cf=tserver-multi.cf");
    add_block "BQ_MULTI_1";

    clear_func_param;
    add_func_param("-cf=tserver-bq.cf");
    add_block "BQ_Stress3D_1";
    add_block "BQ_Stress3D_2";
    
    add_block "BQ_PKStress";
    
    add_sub(sub{ sleep(60); });
    add_prog "./tserverlite -cf=tserver.cf -test=ini1.1";
    
    deinit_flow();

    restore_nature_dpm();

    if (!$args{nobaco}) {
        clear_func_param;
        baco();
    }
}

sub thermaltune_sequence {
    my $speed = shift || 3;

    add_tool "-pcielinkspeed=$speed";
    print "Current PCIe speed: Gen$speed\n";

    clear_func_param;
    add_func_param("-cf=tserver.cf");

    add_block "GPU_INT_LOOP";
    add_block "Check_FP";
    add_block "MEM_INT_LOOP";

    if (!$args{nobaco}) {
        baco();
    }
}

sub chkfp_sequence {
    # CHKFP Testflow
    clear_func_param;
    add_func_param("-cf=tserver-display.cf");
    add_block("Check_FP_LOOP");
    clear_func_param;
    add_func_param("-cf=tserver-chkfp.cf");
    add_block("Check_FP");
}

sub fa2_sequence {
    my $speed = shift || 3;

    dpm();
    clear_func_param;
    add_func_param("-cf=tserver.cf");
    add_block "Stress3D_WITH_NATURE_DPM";
    pm4player_with_nature_dpm();
}

sub gfx {
    clear_func_param;
    add_func_param("-cf=tserver.cf");

    soft_reset();
    add_block "Stress3D_WITH_NATURE_DPM";
    
    add_block "PM4Player";
}

sub baco {
    return if $args{nobaco};
    return if $no_baco_sku;
    clear_func_param;
    add_func_param("-cf=tserver-bamxco.cf");
    add_block "BACO";
}

sub bamaco {
    return if $args{nobaco};
    return if $args{nobamaco};
    return if $no_baco_sku;
    return if $no_bamaco_sku;
    clear_func_param;
    add_func_param("-cf=tserver-bamxco.cf");
    add_block "BAMACO";
}

sub gfxoff {
    clear_func_param;
    add_func_param("-cf=tserver-pm.cf");
    soft_reset();
    add_block "GFXOFF_SANITY";
    soft_reset();
    add_block "STD_GFXOFF";
    soft_reset();
}

sub thermal_external {
    clear_func_param;
    add_func_param("-cf=tserver.cf");
    #add_block "EXTERNAL_THERMAL_LM96163";
    print "External Thermal Test is disabled.\n";
}

sub smbus_board {
    clear_func_param;
    add_func_param("-cf=tserver.cf");
    #add_block "SMBUS_LM96163_ADM1032_EMC2103";
    print "Board SMBus Test is disabled.\n";
}

sub read_vr_manu_id {
    clear_func_param;
    add_func_param("-cf=tserver.cf");
    #add_block "Read_VR_Manu_ID";
    print "Read VR Manufacturer ID Test is disabled.\n";
}

sub svid_bus {
    clear_func_param;
    add_func_param("-cf=tserver.cf");
    #add_block "SVID_BUS";
    print "SVID Bus Test is disabled.\n";
}

sub remote_management {
    clear_func_param;
    add_func_param("-cf=tserver.cf");
    #add_block "REMOTE_MANAGEMENT";
    print "Remote Management Test is disabled.\n";
}

sub smbus_gpu {
    clear_func_param;
    add_func_param("-cf=tserver.cf"); 
    #add_block "SMBUS_GPU";
    print "SMBus GPU Test is disabled.\n";
}

sub usb {
    # Find the USB Controller
    my @usb_devid;
    my $usb_device_string = `./tserverlite -d=? | grep "USB_NAVI23 PF"`;
    my @usb_device_lines = split /\n/, $usb_device_string;
    my $keyword = "USB_NAVI23";
    if (index($usb_device_string, $keyword) != -1) {
        print "Navi23 USB Controller(s) found:\n";
        foreach my $line (@usb_device_lines) {
            my ( $first_word ) = $line =~ /^(\w+)/;
            push @usb_devid, $first_word;
            print "\t$line\n";
        }
    } else {
        push @usb_devid, -1;
        print "[Warn] Navi23 USB Controller Not Found!\n";
    }

    # Run the tests
    if (@usb_devid[0] > 0) {
        foreach my $dev (@usb_devid) {
            clear_func_param;
            soft_reset();
            add_func_param("-cf=tserver.cf -d=$dev -nogc=1");
            add_block "USB_SEQ";
        }
        clear_func_param;
	soft_reset();
	#add_func_param("-cf=tserver.cf -nogc=1");
	#add_block "USB_FLIP";
    }
}

sub ctf {
    return if $args{noctf};    
    my %input;
    $input{"ctfbp"} = read_input("Selections for CTF test:
0 :: Don't run CTF
1 :: Run GPU ASIC CTF
Selection: [0] ", [qw/0 1/], "0", {0=>0, 1=>1});

    if ($input{"ctfbp"}) {
        if ($input{"ctfbp"} == 1) {
            gpu_ctf();
        } else {
            lcs_ctf();
        }
    }
}

sub gpu_ctf {
    clear_func_param;
    if (!$args{noctf}) {
        add_func_param("-cf=tserver-ctf.cf");
	add_block "GPU_CTF";
    }
}

sub lcs_ctf {
    clear_func_param;
    add_func_param("-cf=tserver-ctf.cf");
    add_block "LCS_CTF";
}

sub vcn {
    clear_func_param;
    add_func_param("-cf=tserver.cf");
    add_block "VCN_A_UDEC_Performance_Core_bitstream_tests";
    add_block "VCN_A_MJPEG_bitstream_tests";
    add_block "VCN_A_ENCODE_tests";
    add_block "VCN_A_MULTI_JOB_tests";
}

sub stutter {
    clear_func_param;
    disable_umcch_power_gating();
    enable_dyn_disconnect();
    add_block "Memory-Stutter";
    enable_umcch_power_gating();
}

sub umcpg{
    clear_func_param;
    enable_dyn_disconnect();
    add_block "UMC_PG"
}

sub pm4player_with_nature_dpm {
    add_sub(sub{
        save_env_opt("ignoreforcemax");
        set_env_opt("ignoreforcemax"=>1);
    });

    clear_func_param;
    add_func_param("-cf=tserver.cf");

    add_block "PM4Player_WITH_NATURE_DPM";
    add_block "PM4Player";

    add_sub(sub{restore_env_opt()});
}

sub zero_rpm {
    clear_func_param;
    add_func_param("-cf=tserver.cf");
    add_block("ZERO_RPM");
}

sub SuiteUsage {
    print <<EOF;
BP Suite options:
  -boardtest=quickmfg|quickmfg4|qualmfg4|config|extmfg|memfa|dpm

EOF
}

1;
