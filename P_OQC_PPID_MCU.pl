#!/usr/bin/perl
use 5.010;
#Rev:0.1 Written by Jane 2016-03-28
#Rev:1.0 Update by BIOS Team 2019-09-24
#ChangeList:
#1.Add OC check 
#2.Add MemTune 
#3.Add DUAL BIOS P-Mode check
#Rev:1.2 Update by BIOS Team 2019-10-28
#ChangeList:
#1.Remove OC test item

#Rev:2.0 Update by Jet on 2020-11-04
#changed for NAVI21
#Rev:2.01 Update by Jane 2020-11-09
#Change list: Integrate all the tests and Add LOG File

#Rev:3.00 Update by Jane 2020-12
#Change list: 
#1.Improve LOG details
#2.Delete digital judgement
#3.Add 60-PN in CONF.DAT
#4.Check PPID after flashed PPID

#Rev:4.00 Update
#Change list: 
#1.PPID check illegal Strings
#2.RX6800 retest on error code times

#Rev:4.03 Update
#Change list:
#1.保留 errorid.tmp
#2.ECS PPID取消全数字检查
#3.PPID 长度15位卡关
#4.增加Memory size vendor检查
#5.Config memory size匹配检查
#6.保留log.txt
#7.格式对齐优化调整
 
use subs qw/Log_File Get_PPID Basic_log Start_Time End_Time Test_Date Ram_check Grub_check read_config check_DID check_MEM check_SSID check_LINKWIDTH Q_BIOS_check P_BIOS_check Add_APRP quickmfg oc_Test SPECIAL_TEST/;

$FCT_Version = "4.03";		    # FCT_Version , If Change Must Modify Here
$DIAG_Station = "Diag_P_OQC";	# DIAG_Station 
$ASUS_LOG = "ASUS_P_OQC.log";	# LOG_File
#*****************************************************
#!!Comfirm LOG file NAME!!
#*****************************************************
#FCT --> ASUS_FCT.log /ASUS_P_FCT.log / ASUS_Q_FCT.log
#OQC --> ASUS_OQC.log /ASUS_P_OQC.log / ASUS_Q_OQC.log
#*****************************************************

system "clear";
printf "\e[33m\n";
printf "===============================================\n";
printf "        	 ASUS FCT                          \n";
printf "         Rev $FCT_Version . Changed in 2021-06 \n";
printf "===============================================\n";
printf "\n\e[0m";

system "rm -f errorid.tmp";
system "rm -f $ASUS_LOG";

#=======================================================
#                      Main Function
#=======================================================
&read_config();		#Read Config file
&Get_PPID();
&Basic_log();
&Get_ASIC_Serial_Number();
&Get_BIOS_Version();
&check_DID();
&check_SSID();
&Get_Diag_Version();
#&Get_BIOS_PN();
&Get_System_info();
&Test_Date();
&check_MEM();
&check_LINKWIDTH();
#&Ram_check();	#For Factory Test_Platform check
#&Grub_check();
#&Q_BIOS_check();
&P_BIOS_check();
#&quickmfg();
#&oc_Test();		#FCT
#&train_Tune();
#&strobe_Tune();
&MCU_FUNCTION();
#&FAN_Test();
#&SPECIAL_TEST();
#&Add_APRP();	#APRP #FCT1
&Check_PPID(); #FCT #OQC

if ( $? ne 0 )
{
	&ShowFail();

}else
{
	&ShowPass();
}

#=======================================================
#             		LOG File
#=======================================================
sub Log_File()
{
	$asus_log = $asus_log.' | '."FCT_v$FCT_Version";
	open logfile,"> $ASUS_LOG";
	select logfile ;
	print $asus_log."\r\n";

	select stdout;
}
#=======================================================
#             Read Config DATA File
#=======================================================
sub read_config()
{
	$file = "FCT_CONF.DAT";
	if (-e $file )
	{
		printf "\e[33m\n";
		printf "------------- Config File Data Info --------------\n";

		$read_line = `cat $file |grep OEM`;
		chomp( $read_line ); #Get OEM
		@OEM =split /=/,$read_line ; 	   #$OEM[1] = NIS or ECS     	
		print "OEM\t\t = $OEM[1] \n" ;

		$read_line = `cat $file |grep DID`;
		chomp($read_line ); #Get DID
		@DID =split /=/,$read_line ; 	  #Device ID   	
		print "DeviceID\t = $DID[1] \n" ;

		$read_line = `cat $file |grep SSID`;
		chomp($read_line ); #Get SSID
		@SSID =split /=/,$read_line ;      #Subsystem ID       	
		print "SSID\t\t = $SSID[1] \n" ;

		$read_line = `cat $file |grep LINKWIDTH`;
		chomp($read_line ); #Get LinkWidth
		@LINKWIDTH =split /=/,$read_line ; #Link Width       	
		print "LinkWidth\t = $LINKWIDTH[1] \n" ;

		$read_line = `cat $file |grep 60PN`;
		chomp($read_line ); #Get 60PN
		@PN =split /=/,$read_line ;       	 
		print "60PN\t\t = $PN[1] \n";

		$read_line = `cat $file |grep MODELNAME`;
		chomp($read_line ); #Get Modelname
		@MODELNAME =split /=/,$read_line ;       	 
		print "ModelName\t = $MODELNAME[1] \n";

		$read_line = `cat $file |grep DUALBIOS`;
		chomp($read_line ); #Get DUAL BIOS or not 
		@DUALBIOS =split /=/,$read_line ;       	 
		print "DUALBIOS\t = $DUALBIOS[1] \n";     

		$read_line = `cat $file |grep QUICK_PARAMETERS`;
		chomp($read_line ); #Get QUICK_PARAMETERS
		@QUICK_PARAMETERS =split /=/,$read_line ;       	 
		print "QUICK_PARM\t = $QUICK_PARAMETERS[1] \n";

		$read_line = `cat $file |grep OCTEST`;
		chomp($read_line ); #Get OC TEST
		@OCTEST =split /=/,$read_line ;       	 
		print "OCTEST\t\t = $OCTEST[1] \n";

		$read_line = `cat $file |grep TRAINTUNE`;
		chomp($read_line ); #Get Mem Training mode margintest
		@TRAINTUNE =split /=/,$read_line ;       	 
		print "TRAINTUNE\t = $TRAINTUNE[1] \n";

		$read_line = `cat $file |grep STROBETUNE`;
		chomp($read_line ); #Get Mem Strobe mode margintest
		@STROBETUNE =split /=/,$read_line ;       	 
		print "STROBETUNE\t = $STROBETUNE[1] \n";

		$read_line = `cat $file |grep MCU_FUNCTION`;
		chomp($read_line ); #Get MCU Function Test
		@MCU_FUNCTION =split /=/,$read_line ;       	 
		print "MCU_FUNCTION\t = $MCU_FUNCTION[1] \n";

		$read_line = `cat $file |grep FANTEST`;
		chomp($read_line ); #Get FAN Test
		@FANTEST =split /=/,$read_line ;       	 
		print "FANTEST\t\t = $FANTEST[1] \n";
		
		$read_line = `cat $file |grep SPECIAL_TEST`;
		chomp($read_line ); #Get SPECIAL_TEST
		@SPECIAL_TEST =split /=/,$read_line ;       	 
		print "SPECIAL_TEST\t = $SPECIAL_TEST[1] \n";
		
		$read_line = `cat $file |grep AUTO_RETEST`;
		chomp($read_line ); #Get AUTO_RETEST
		@AUTO_RETEST =split /=/,$read_line ;       	 
		print "AUTO_RETEST\t = $AUTO_RETEST[1] \n";
		
		$read_line = `cat $file |grep MEM_Size`;
		chomp($read_line ); #Get MEM_Size
		@MEM_Size =split /=/,$read_line ;       	 
		print "MEM_Size\t = $MEM_Size[1] \n";	
		
		$read_line = `cat $file |grep MEM_Vendor_Type`;
		chomp($read_line ); #Get MEM_Vendor_Type
		@MEM_Vendor_Type =split /=/,$read_line ;       	 
		print "MEM_Vendor_Type\t = $MEM_Vendor_Type[1] \n";
		
		printf "--------------------------------------------------\n";
		printf "\n\e[0m";

 		print "=============================\n";
		print "	 TESTING NOW ... ... \n";
 		print "=============================\n";

}
	else
	{
		print "Can't Find Config File FCT_CONF.DAT , Please Double Check . \n\n";
		&ShowFail(); 
	}

}
#=======================================================
#					Get PPID String
#=======================================================

sub Get_PPID()
{

	#Confirm OEM and get PPID by scanning SN label
	if( $OEM[1] eq "NIS" )
	{
		$Lableppid=`cat /host/tools/SFIS.DAT`;
		if( $? ne 0 ) 
		{
			print "\e[31mCan't find SFIS.DAT  !\n\e[0m";
			exit 1;
        }
  	}
	elsif( $OEM[1] eq "ECS" )
	{
		$Lableppid=`cat result.dat |grep "SN"`;
		chomp($Lableppid);
		@tt = split (/:/,$Lableppid);
		$Lableppid = $tt[1];
		$Lableppid =~s/(^\s+|\s+$)//g;
		if( $? ne 0 )
		{  
			print "\e[31mCan't find result.dat  !\n\e[0m";
			exit 1;
		}
	}
	else
	{
 		printf "\e[31m=====================\e[0m\n";
		printf "\e[31m Cannot confirm OEM !\e[0m\n";
		printf "\e[31m=====================\e[0m\n";
		&ShowFail();
	}
	if( $Lableppid eq "" )
	{
		print "\e[31mThe ppid scanned from SN label is empty !\e[0m\n\n";
		&ShowFail();
	}

	chomp($Lableppid);
	my $len=length($Lableppid);
	if( $len ne 15 )
	{  
	     print "\e[31mPPID Length is not 15 bytes  !\n\e[0m";
	     exit 1;
	}
	print "PPID\t\t = $Lableppid\n";
    	$asus_log = $Lableppid;		
}	


#=======================================================
#             Record Basic Info to Log
#=======================================================
sub Basic_log{
	
	print "Diag_Station\t = $DIAG_Station\n";
	$asus_log = $asus_log.' | '."$DIAG_Station";
	
	$PN = $PN[1];
	print "60PN\t\t = $PN\n";
	$asus_log = $asus_log.' | '."$PN";
	
	$MN = $MODELNAME[1];
	chop($MN);
	print "Model_Name\t = $MN\n";
	$asus_log = $asus_log.' | '."$MN";
	
}

#==========================================================
#                  Get ASIC Serial Number                 =
#==========================================================
sub Get_ASIC_Serial_Number()
{

	$asic_serial_num=`./agt -sid |grep SerialID`;

	@tmp = split(/=/,$asic_serial_num); # Get ASIC Serial Num 
	chomp($asic_serial_num = $tmp[1]);
	$asic_serial_num=~s/(^\s+|\s+$)//g;
	
	print "GPU_SID\t\t = $asic_serial_num\n";
	$asus_log = $asus_log.' | '.$asic_serial_num;
}

#==========================================================
#                  Get BIOS Version                       =
#==========================================================
sub Get_BIOS_Version()
{


		$BIOS_VER=`./amdvbflash -ai |grep Product`;
        chomp($BIOS_VER);
		@tt = split (/:/,$BIOS_VER);
		$BIOS_VER = $tt[1];
		$BIOS_VER =~s/(^\s+|\s+$)//g;
		if ($BIOS_VER eq "")
		{
			$BIOS_VER="NULL" ;
		}	 
		
		print "BIOS_Version\t = $BIOS_VER\n";
      	$asus_log = $asus_log.' | '.$BIOS_VER ;
}


#==========================================================
#                  Get Diag Version                       =
#==========================================================
sub Get_Diag_Version()
{

	if (-e "tserverlite" )
	{
		`./tserverlite -version 2>tmp`; # Get Diag Version
		$tmp_diag_version = `cat tmp |grep Version`;
		@tmp = split(/:/,$tmp_diag_version);#AMD Diag Version
		chomp($tmp_diag_version = $tmp[1]);
		$tmp_diag_version=~s/(^\s+|\s+$)//g; #Remove space
		
		print "Diag_Version\t = $tmp_diag_version\n";
		$asus_log = $asus_log.' | '.$tmp_diag_version;		
	}


}

#==========================================================
#                  Get BIOS PN                            =
#==========================================================
sub Get_BIOS_PN()
{


		$BIOS_PN=`./agt -biospn |grep Number`;
        chomp($BIOS_PN);
		@tt = split (/:/,$BIOS_PN);
		$BIOS_PN = $tt[1];
		$BIOS_PN =~s/(^\s+|\s+$)//g;
		if ($BIOS_PN eq "")
		{
			$BIOS_PN="NULL" ;
		}	 

		print "BIOS_PN\t\t = $BIOS_PN\n";		
      	$asus_log = $asus_log.' | '.$BIOS_PN ;
}


#==========================================================
#                  Get System info                        =
#==========================================================
sub Get_System_info()
{
#Get MB_Name
		$MB_Name=`dmidecode -t 2 |grep "Product Name"`;
        chomp($MB_Name);
		@tt = split (/:/,$MB_Name);
		$MB_Name = $tt[1];
		$MB_Name =~s/(^\s+|\s+$)//g;
		if ($MB_Name eq "")
		{
			$MB_Name="NULL" ;
		}	
		
		print "MB_Name\t\t = $MB_Name\n";		
      	$asus_log = $asus_log.' | '.$MB_Name ;
		
#Get MB_SN		
		$MB_SN=`dmidecode -t 2 |grep "Serial Number"`;
        chomp($MB_SN);
		@tt = split (/:/,$MB_SN);
		$MB_SN = $tt[1];
		$MB_SN =~s/(^\s+|\s+$)//g;
		if ($MB_SN eq "")
		{
			$MB_SN="NULL" ;
		}	 
		
		print "MB_SN\t\t = $MB_SN\n";
      	$asus_log = $asus_log.' | '.$MB_SN ;

#Get CPU_Name		
		$CPU_Name=`cat /proc/cpuinfo |grep "model name" | head -n 1`;
        chomp($CPU_Name);
		@tt = split (/:/,$CPU_Name);
		$CPU_Name = $tt[1];
		$CPU_Name =~s/(^\s+|\s+$)//g;
		if ($CPU_Name eq "")
		{
			$CPU_Name="NULL" ;
		}	 
		
		print "CPU_Name\t = $CPU_Name\n";
      	$asus_log = $asus_log.' | '.$CPU_Name ;
}


#=======================================================
#             Record Time
#=======================================================


sub Start_Time{
	$Start_time =`date +%H:%M:%S`;
	chomp($Start_time);
}

sub End_Time{
	$End_time =`date +%H:%M:%S`;
	chomp($End_time);		
	#print "End_Time = $End_time\n";
			
	@Sitem = split /:/, $Start_time;
	@Eitem = split /:/, $End_time;

	$Delta_time = $Eitem[0] * 3600 + $Eitem[1] * 60 + $Eitem[2] - $Sitem[0] * 3600 - $Sitem[1] * 60 -$Sitem[2];
	#print "	$Delta_time = $Eitem[0] * 3600 + $Eitem[1] * 60 + $Eitem[2] - $Sitem[0] * 3600 - $Sitem[1] * 60 -$Sitem[2];\n";

	if($Delta_time < 0)
	 {
		$Delta_time += 86400;
	}
	#print "Delta_Time = $Delta_time\n";

	$asus_log = $asus_log.' | '.$Start_time;		
	$asus_log = $asus_log.' | '.$End_time;		
	$asus_log = $asus_log.' | '.$Delta_time;		
}
sub Test_Date{
	$Test_Date = `date "+%Y-%m-%d"`;
	chomp($Test_Date);

	print "Test_Date\t = $Test_Date\n";
	$asus_log = $asus_log.' | '.$Test_Date;		
	
}

#=======================================================
#             Check System RAM Capacity
#=======================================================
sub Ram_check()
{
	@RAM_CAP =  `dmidecode -t memory|grep -i \'size\' |grep -o \'[0-9]*\'` ;
	my $sum = 0;
	foreach $get (@RAM_CAP)
	{
		$sum += $get;
		#print "sum is $sum\n";
	}

	print "System's_DRAM\t = $sum MB\n";	
	if ( $sum < 8192)
	{
		print "\e[31mThe system DRAM is less than 8192MB!!! \e[0m\n\n";
		&ShowFail();
	}
}

#=======================================================
#             Check Grub DRAM setting
#=======================================================		
sub Grub_check()
{
	$grub_set = `grep -io \'mem=[0-9]\\{1,10\\}\' /etc/default/grub | cut -d \'=\' -f 2` ;
	chomp($grub_set);
	#print "\$grub_set is $grub_set MB\n";
	if ( $grub_set ne "4096")
	{
		print "\e[31mThe Grub's DRAM setting is not 4096M !!! \e[0m\n\n";
		&ShowFail();
	}	
}


#=======================================================
#                      Check Device ID
#=======================================================
sub check_DID()
{
	$cmd_temp=`./amdvbflash -ai |grep -o [0-F][0-F][0-F][0-F]1002 |cut -c 1-4`;
	chomp($cmd_temp);
	$BIOS_DID = $cmd_temp;
	print "BIOS_DID\t = $BIOS_DID \n" ;
	$asus_log = $asus_log.' | '.$BIOS_DID;		

	if( $BIOS_DID eq $DID[1])
	{
	}
	else
	{
		printf "\e[31m================== \e[0m\n";
		printf "\e[31m Check DID Fail ! \e[0m\n";
		printf "\e[31m================== \e[0m\n";
		&ShowFail();
	}
}
#=======================================================
#                      Check SSID
#=======================================================
sub check_SSID()
{
	$cmd_temp=`./amdvbflash -ai |grep -o [0-F][0-F][0-F][0-F]1043 |cut -c 1-4`;
	chomp($cmd_temp);
	$BIOS_SSID = $cmd_temp;
	print "BIOS_SSID\t = $BIOS_SSID \n" ;
	$asus_log = $asus_log.' | '.$BIOS_SSID;		
	
	if( $BIOS_SSID eq $SSID[1])
	{
	}
	else
	{
		printf "\e[31m=================== \e[0m\n";
		printf "\e[31m Check SSID Fail ! \e[0m\n";
		printf "\e[31m===================\e[0m\n";
		&ShowFail();
	}
}

#=======================================================
#                      VGA MEM check
#=======================================================
sub check_MEM()
{
	$memory_info=`./agt -mccfg`;
	my @memory_string_lines = split("\n", $memory_info);
	foreach my $memory_string_line (@memory_string_lines)
	{
		#memoy vendor tpye check
		if($memory_string_line =~ m/Memory vendor/)
		{
			@mem_vendor = split(/:/,$memory_string_line); 
			chomp($mem_vendor = $mem_vendor[1]);
			$mem_vendor=~s/(^\s+|\s+$)//g;
			print "MEM_Vendor_Type\t = $mem_vendor \n" ;
            if( $mem_vendor ne $MEM_Vendor_Type[1])
	        {
			printf "\e[31m============================= \e[0m\n";	
			printf "\e[31m Check MEM vendor type Fail ! \e[0m\n";
			printf "\e[31m============================= \e[0m\n";	
		    &ShowFail();
	        }
		}
		#memoy size check
		if($memory_string_line =~ m/Calculated memory size/)
		{
			@mem_Calculated_size = split(/:/,$memory_string_line); 
			chomp($mem_Calculated_size = $mem_Calculated_size[1]);
			$mem_Calculated_size=~s/(^\s+|\s+$)//g;
			print "MEM_CALC_size\t = $mem_Calculated_size \n" ;
		    if( $mem_Calculated_size ne $MEM_Size[1])
	        {
			printf "\e[31m====================== \e[0m\n";	
			printf "\e[31m Check MEM size Fail ! \e[0m\n";
			printf "\e[31m====================== \e[0m\n";	
		    &ShowFail();
	        }
		}
	}
	   @tt01 = split (/MB/,$MEM_Size[1]);
	   $MEM_Size = @tt01[0] ;
	   $MEM_Size =~s/(^\s+|\s+$)//g;
	   
	   $MEM_Size =$MEM_Size / 1024;
	   $MEM_Size .="G";
	   # print "MEM_Size\t = $MEM_Size \n";
	   # print "Model_name\t = $MODELNAME[1] \n";
	   if($MODELNAME[1] !~ $MEM_Size)
	   {
		   	printf "\e[31m============================ \e[0m\n";	
			printf "\e[31m MEM size config not match ! \e[0m\n";
			printf "\e[31m============================ \e[0m\n";	
		    &ShowFail();
       }
}

#=======================================================
#                      Check LINK WIDTH
#=======================================================
sub check_LINKWIDTH()
{
	$cmd_temp=`./agt -pciestatus |grep -oi 'x[1-9]\\{1,2\\}'`;
	chomp($cmd_temp);
	print "LINKWIDTH_Value\t = $cmd_temp \n" ;

	if( $cmd_temp eq $LINKWIDTH[1])
	{
	}
	else
	{
		printf "\e[31m=================== \e[0m\n";
		printf "\e[31m Check LINLWIDTH Fail ! \e[0m\n";
		printf "\e[31m===================\e[0m\n";
		&ShowFail();
	}
}


#=======================================================
#                  DUAL BIOS(P/Q) CHECK
#=======================================================

sub Q_BIOS_check{
#Add Q-mode check
	if( $DUALBIOS[1] eq 1 )
	{
		$cmd_temp = `./amdvbflash -ai|grep Product`;
		@BIOS_Version = split /\./,$cmd_temp ; 
		chomp($BIOS_Version[5]);
		if ($BIOS_Version[5]  =~ /Q/i)
		{
			printf "\e[32mBIOS_Mode\t = $BIOS_Version[5]\e[0m\n";   
		}else
		{
			printf "\e[31mBIOS_Mode\t = $BIOS_Version[5] --->   Check FAIL. \e[0m\n"; 
			printf "\e[31mBIOS Version mismatched~! Please check Vbios!\n\e[0m \n";
			&ShowFail();
	        }
		print"\n";
		sleep 1; 
	}
#Add Q-mode check End
}

sub P_BIOS_check{
#	Add P-mode check
	if( $DUALBIOS[1] eq 1 )
	{
		$cmd_temp = `./amdvbflash -ai|grep Product`;
		@BIOS_Version = split /\./,$cmd_temp ; 
		chomp($BIOS_Version[5]);
		if ($BIOS_Version[5]  =~ /P/i)
		{
			printf "\e[32mBIOS_Mode\t = $BIOS_Version[5]\e[0m\n";   
		}else
		{
	      		printf "\e[31mBIOS_Mode\t = $BIOS_Version[5] --->   Check FAIL. \e[0m\n"; 
	          	printf "\e[31mBIOS Version mismatched~! Please check Vbios!\n\e[0m \n";
	          	&ShowFail();
	        }
		print"\n";
		sleep 1; 
	}
}

#=======================================================
#                      ADD APRP
#=======================================================
sub Add_APRP()
{
	&Start_Time;
	#Get PPID from VGA BIOS ROM
	system `./amdvbflash -s 0 ppid.rom >/dev/null`;
	$ppidstr = `dd if=./ppid.rom bs=2k 2>/dev/null |strings|grep PPID`;
	@Romppid =  split /\#|]/, $ppidstr ; #$Romppid = ppid number (CTZXXXXXXXXXXx)
	chomp($Romppid[1]);
	system "rm ppid.rom";

	if ( $Romppid[1] ne "" )
	{
		if ($Romppid[1] eq $Lableppid )
		{
			print "\e[32mThe PPID has been already flashed !\e[0m\n\n";
			$asus_log = $asus_log.' | '."Add_APRP: Pass";		
			&End_Time;
			return 0;
		}
		else
		{	
			if( $Lableppid eq "")
			{
				print "\e[31mThe ppid scanned from SN label is empty !\e[0m\n\n";
				$asus_log = $asus_log.' | '."Add_APRP: Fail";		
				&End_Time;
				&ShowFail();
			}
			
		   	print "\033[31mPPIDs are mis-match compared between BIOS ROM and SN Label !\033[0m\n\n";
			$asus_log = $asus_log.' | '."Add_APRP: Fail";		
			&End_Time;
		   	&ShowFail();
		}
	}

	chomp($MODELNAME[1]);
	print "OEM : $OEM[1] \n";
	print "$OEM[1] PPID: $Lableppid \n";
	#<STDIN>; #check point only
 	
	open  PP, "> ppid.txt";
	print PP "PPID";
	print PP "$MODELNAME[1]";
	print PP "$Lableppid";
	close PP;
	
	system "./pn128_2018";
	system "./amdvbflash -p 0 org.rom";
	if ( $? ne 0 )  #update bios fail !
	{
		printf "\e[31mUpdate APRP to BIOS ROM Failed !!!\n\n\e[0m";
		$asus_log = $asus_log.' | '."Add_APRP: Fail";		
		&End_Time;
		&ShowFail();
	}
	
	system "./amdvbflash -s 0 bios.rom";
	system "diff org.rom bios.rom";
	if ( $? ne 0 )  #Compare BIOS !
	{
		printf "\e[31mUpdate APRP to BIOS ROM Failed !!!\n\n\e[0m";
		$asus_log = $asus_log.' | '."Add_APRP: Fail";		
		&End_Time;
		&ShowFail();
	}
		
	$asus_log = $asus_log.' | '."Add_APRP: Pass";		
	&End_Time;
}

#=======================================================
#                      CHECK PPID
#=======================================================
sub Check_PPID()
{
	&Start_Time;
	system './amdvbflash -s 0 ppid.rom >/dev/null';
	$ppidstr = `dd if=./ppid.rom bs=2k 2>/dev/null |strings|grep PPID`;
	@ppidnum =  split /\#|]/, $ppidstr ; #$ppidnum = ppid number (CTZXXXXXXXXXXx)
	chomp($ppidnum[1]);
        system "rm ppid.rom";
			
	chomp($Lableppid);
	print "---------------------------\n";
	print "BIOS PPID=$ppidnum[1]\n";
	print "DATA PPID=$Lableppid\n";
	print "---------------------------\n";
	if ( $ppidnum[1] eq "" )
	{
		print "\033[31mCan't Find BIOS ROM PPID Strings \033[0m\n\n";
		print "\033[31mPPID Flash Fail !\033[0m\n";
		$asus_log = $asus_log.' | '."Check_PPID: Fail";		
		&End_Time;
		&ShowFail();
	}

		$ppidtemp = $ppidnum[1];
		$ppidtemp =~ tr/0-9/ /d;
		$ppidtemp =~ tr/a-z/ /d;
		$ppidtemp =~ tr/A-Z/ /d;
		$ppidtemp =~ tr/\t //d;
	
	if ($ppidtemp ne "" )
	{
		print "\033[31mFind Bios Data PPID contain illegal Strings \033[0m\n\n";
		print "\033[31mPPID Flash Fail !\033[0m\n";
		$asus_log = $asus_log.' | '."Check_PPID: Fail";		
		&End_Time;
		&ShowFail();
	}

	if ($Lableppid eq "" )
	{
		print "\033[31mCan't Find Data PPID Strings \033[0m\n\n";
		print "\033[31mPPID Flash Fail !\033[0m\n";
		$asus_log = $asus_log.' | '."Check_PPID: Fail";		
		&End_Time;
		&ShowFail();
	}


	if ($ppidnum[1] eq $Lableppid )
	{
		print "\033[32mPPID Flash Successful !\033[0m\n\n";
		$asus_log = $asus_log.' | '."Check_PPID: PASS";		
		&End_Time;
	}
	else
	{
		print "\033[31mPPID Flash Fail !\033[0m\n\n\n\n\n";
		$asus_log = $asus_log.' | '."Check_PPID: Fail";		
		&End_Time;
		&ShowFail();
	}
}

#=======================================================
#                      RUN QUICKMFG
#=======================================================
sub quickmfg()
{
	&Start_Time;
	if( $QUICK_PARAMETERS[1] ne 0)
	{
		$Add_parameter = "$QUICK_PARAMETERS[1]";
	}
	else 
	{
		$Add_parameter="";
	}
	
	#Get PCIE LINK SPEED
	$cmd_temp=`./agt -pciestatus | grep -i 'Link Speed = '`;
	@cmd_temp=split / = /,$cmd_temp;
	@cmd_temp=split /\s+/,$cmd_temp[1];
	$gen_check = $cmd_temp[0];	
	print "PCIE\t\t = $gen_check\n";
	
	if( $gen_check eq "GEN4" )
	{
		print "Run Quickmfg Gen4\n";
		print "./tserver -boardtest=quickmfg4 -nw -noctf $Add_parameter\n";
		system "./tserver -boardtest=quickmfg4 -nw -noctf $Add_parameter";
		if( $? ne "0" && $AUTO_RETEST[1] ne 0)
		{
			printf "\e[31mGen4 DIAG test failed ! \n\e[0m";
			$asus_log = $asus_log.' | '."quickmfg: Fail";		
			$error_id = `cat errorid.tmp`;
			chomp($error_id);
			$asus_log = $asus_log.' | '."ErrorID: $error_id";		
			&End_Time;
			print "Run Quickmfg Gen4 Aging\n";
		    print "./tserver -boardtest=quickmfg4 -nw -noctf $Add_parameter\n";
		    system "./tserver -boardtest=quickmfg4 -nw -noctf $Add_parameter";
			# &ShowFail();
		if( $? ne "0")
		   {
			printf "\e[31mGen4 DIAG test failed ! \n\e[0m";
			$asus_log = $asus_log.' | '."quickmfg: Fail";		
			$error_id = `cat errorid.tmp`;
			chomp($error_id);
			$asus_log = $asus_log.' | '."ErrorID: $error_id";		
			&End_Time;
		    &ShowFail();
	       }
		}
		if( $? ne "0")
		   {
			printf "\e[31mGen4 DIAG test failed ! \n\e[0m";
			$asus_log = $asus_log.' | '."quickmfg: Fail";		
			$error_id = `cat errorid.tmp`;
			chomp($error_id);
			$asus_log = $asus_log.' | '."ErrorID: $error_id";		
			&End_Time;
		    &ShowFail();
	       }
	
	}
	elsif( $gen_check eq "GEN3")
	{
		print "Run Quickmfg Gen3\n";
		print "./tserver -boardtest=quickmfg -nw -noctf $Add_parameter\n";
		system "./tserver -boardtest=quickmfg -nw -noctf $Add_parameter";
		if( $? ne "0" && $AUTO_RETEST[1] ne 0)
		{
			printf "\e[31mGen3 DIAG failed ! \n\e[0m";
			$asus_log = $asus_log.' | '."quickmfg: Fail";		
			$error_id = `cat errorid.tmp`;
			chomp($error_id);
			$asus_log = $asus_log.' | '."ErrorID: $error_id";		
			&End_Time;
			print "Run Quickmfg Gen3\n";
		    print "./tserver -boardtest=quickmfg -nw -noctf $Add_parameter\n";
		    system "./tserver -boardtest=quickmfg -nw -noctf $Add_parameter";
			#&ShowFail();
		
		if( $? ne "0")
		{
			printf "\e[31mGen3 DIAG failed ! \n\e[0m";
			$asus_log = $asus_log.' | '."quickmfg: Fail";		
			$error_id = `cat errorid.tmp`;
			chomp($error_id);
			$asus_log = $asus_log.' | '."ErrorID: $error_id";		
			&End_Time;
			&ShowFail();
		}
		}
		if( $? ne "0")
		{
			printf "\e[31mGen3 DIAG failed ! \n\e[0m";
			$asus_log = $asus_log.' | '."quickmfg: Fail";		
			$error_id = `cat errorid.tmp`;
			chomp($error_id);
			$asus_log = $asus_log.' | '."ErrorID: $error_id";		
			&End_Time;
			&ShowFail();
		}
	}
	else
	{
		print "------------------------------------------------------------\n";
		print "PCI-E Link Error! Make sure Gen3 or Gen4 link for DIAG test.\n";
		&ShowFail();
	}

	if ( -e "quick.txt" )
	{
		system "rm quick.txt";	
	}
	system "cp log.txt quick.txt";

	if ( -e "quick.yml" )
	{
		system "rm quick.yml";
	}
	system "cp log.yml quick.yml";
	
	system "cat errorid.tmp |grep PASS";
	if ( $? eq 0 )
	{
		#print logfile "quickmfg: Pass |";
		$asus_log = $asus_log.' | '."quickmfg: Pass";		
		&End_Time;
	}else
	{
		#print logfile "quickmfg: Fail |";
		$asus_log = $asus_log.' | '."quickmfg: Fail";		
		$error_id = `cat errorid.tmp`;
		chomp($error_id);
		$asus_log = $asus_log.' | '."ErrorID: $error_id";		
		&End_Time;
		&ShowFail();
	}
}

#=======================================================
#                      RUN OC TEST
#=======================================================
sub oc_Test()
{
	if( $OCTEST[1] eq 1 )
	{
        &Start_Time;
	    system "rm -f errorid.tmp";
		print "Run chkfp test...\n";
		print "./tserver -boardtest=chkfp";
		system "./tserver -boardtest=chkfp";
		if( $? ne "0")
		{
			printf "\e[31mChkfp Test failed ! \n\e[0m";
			$asus_log = $asus_log.' | '."Chkfp_Test: Fail";		
			$error_id = `cat errorid.tmp`;
			chomp($error_id);
			$asus_log = $asus_log.' | '."ErrorID:$error_id";		
			&End_Time;
			&ShowFail();
		}
			
		system "cat errorid.tmp |grep PASS";
		if ( $? eq 0 )
		{
			$asus_log = $asus_log.' | '."Chkfp_Test: Pass";		
			&End_Time;
		}else
		{
			$asus_log = $asus_log.' | '."Chkfp_Test: Fail";		
			&End_Time;
			&ShowFail();
		}
	}
}

#=======================================================
#                      RUN Mem Training mode test
#=======================================================
sub train_Tune()
{	
	if( $TRAINTUNE[1] eq 1)
	{
		&Start_Time;
		my $vendor = `./agt -mccfg |grep -io MICRON`;
		chomp $vendor ;
		#print "The Memory vendor is $vendor\n";
		if ( $vendor eq "MICRON" )
		{
			print "./agt -ppoverride=pptable.bin -ppmode=1" ;
			#<STDIN>;
			system "./agt -ppoverride=pptable.bin -ppmode=1";
		}else
		{
			print "./agt -ppmode=1" ;
			#<STDIN>;
			system './agt -ppmode=1' ;
		}
		print "./agt -ppdpmforce=mclk,max" ;
		system './agt -ppdpmforce=mclk,max' ;
		print "./memtune margintest -testfile=2dx.sh" ;
		system './memtune margintest -testfile=2dx.sh';
		if ( $? ne 0 )
		{
			print "Mem training margin test Error!!!\n\n\n" ;
			$asus_log = $asus_log.' | '."Train_Tune: Fail";		
			&End_Time;
			&ShowFail();
		}

		$asus_log = $asus_log.' | '."Train_Tune: Pass";		
		&End_Time;
	}	
}

#=======================================================
#                      RUN Mem Strobe mode test
#=======================================================
sub strobe_Tune()
{	
	&Start_Time;
	if( $STROBETUNE[1] eq 1)
	{
		print "./agt -ppmode=1" ;
		system './agt -ppmode=1' ;
		print "./agt -ppdpmforce=mclk,min" ;
		system './agt -ppdpmforce=mclk,min' ;
		print "./memtune margintest_strobe -testfile=2dx.sh" ;
		system './memtune margintest_strobe -testfile=2dx.sh';
		if ( $? ne 0 )
		{
			print "Mem strobe margin test Error!!!\n\n\n" ;
			$asus_log = $asus_log.' | '."Strobe_Tune: Fail";		
			&End_Time;
			&ShowFail();
		}
		$asus_log = $asus_log.' | '."Strobe_Tune: Pass";		
		&End_Time;
	}	
}

#=======================================================
#                      RUN MCU_FUNCTION TEST
#=======================================================
sub MCU_FUNCTION()
{
	&Start_Time;
	#$asus_log = $asus_log.' | '."DIAG_F2 ";
	if( $MCU_FUNCTION[1] ne 0)
	{
		print "$MCU_FUNCTION[1] test begin...\n";
		system "./$MCU_FUNCTION[1]";
		if ( $? ne 0 )
		{
			#printf "\e[31m MCU FUNCTION Test Failed.. !!!\n\n\e[0m";
			$asus_log = $asus_log.' | '."$MCU_FUNCTION[1]: Fail";		
			&End_Time;
			&ShowFail();
		}
		$asus_log = $asus_log.' | '."$MCU_FUNCTION[1]: Pass";		
		&End_Time;
	}

}
#=======================================================
#                      RUN SPECIAL TEST
#=======================================================
sub SPECIAL_TEST()
{
	&Start_Time;
	if( $SPECIAL_TEST[1] ne 0)
	{
		print "$SPECIAL_TEST[1] test begin...\n";
		system "./$SPECIAL_TEST[1]";
		if ( $? ne 0 )
		{
			$asus_log = $asus_log.' | '."$SPECIAL_TEST[1]: Fail";		
			&End_Time;
			&ShowFail();
		}
		$asus_log = $asus_log.' | '."$SPECIAL_TEST[1]: Pass";		
		&End_Time;
	}

}

#=======================================================
#                      RUN FAN TEST
#=======================================================
sub FAN_Test()
{
	&Start_Time;
	if( $FANTEST[1] ne 0)
	{

		print "FAN test begin...";
		system "./gpio-b-fan";
		system "./$FANTEST[1]";
		if ( $? ne 0 )
		{
			printf "\e[31m FAN test Failed.. !!!\n\n\e[0m";
			#print logfile "FAN_Test: Fail |";
			$asus_log = $asus_log.' | '."$FANTEST[1]: Fail";		
			&End_Time;
			&ShowFail();
		}
		#print logfile "FAN_Test: Pass |";
		$asus_log = $asus_log.' | '."$FANTEST[1]: Pass";		
		&End_Time;
	
	}
}


sub ShowPass()
{
	&Log_File();
    printf  "\e[32m\n";
    print "PPPPPPPP          AAA            SSSSS            SSSSS     \n";
    print  "PPPPPPPPPP       AAAAA         SSSSSSSSSS       SSSSSSSSSS  \n";
    print  "PPP     PPP     AAA AAA       SSS     SSSS     SSS     SSSS \n";
    print  "PPP     PPP    AAA   AAA      SSS              SSS		\n";
    print  "PPPPPPPPPP    AAA     AAA      SSS              SSS		\n";
    print  "PPPPPPPP      AAA     AAA        SSSS             SSSS	\n";
    print  "PPP           AAA     AAA          SSSS             SSSS	\n";
    print  "PPP           AAAAAAAAAAA            SSSS             SSSS	\n";
    print  "PPP           AAAAAAAAAAA              SSS              SSS	\n";
    print  "PPP           AAA     AAA     SSSS     SSS     SSSS     SSS	\n";
    print  "PPP           AAA     AAA      SSSSSSSSSS       SSSSSSSSSS	\n";
    print  "PPP           AAA     AAA         SSSSS            SSSSS	\n";
    printf  "\e[0m\n\n";
    exit 0 ;
}


sub ShowFail()
{   
	&Log_File();
	printf  "\e[31m\n";
    print  "FFFFFFFFF         AAA         IIIIIIIII     LLL        \n";
    print  "FFFFFFFFF        AAAAA        IIIIIIIII     LLL        \n";
    print  "FFF             AAA AAA          III        LLL        \n";
    print  "FFF            AAA   AAA         III        LLL        \n";
    print  "FFF           AAA     AAA        III        LLL        \n";
    print  "FFFFFFFF      AAA     AAA        III        LLL        \n";
    print  "FFFFFFFF      AAA     AAA        III        LLL        \n";
    print  "FFF           AAAAAAAAAAA        III        LLL        \n";
    print  "FFF           AAAAAAAAAAA        III        LLL        \n";
    print  "FFF           AAA     AAA        III        LLL        \n";
    print  "FFF           AAA     AAA     IIIIIIIII     LLLLLLLLLLL\n";
    print  "FFF           AAA     AAA     IIIIIIIII     LLLLLLLLLLL\n";
	print "\n\nPress any key to continue...";
    printf "\n\n\e[0m";
    <STDIN>;
    #close logfile;
    exit 110 ;
}
