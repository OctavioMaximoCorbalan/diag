#! /usr/bin/perl
use 5.010;

#Change List:
#Write by Jane 2021-01

#==========================================================
#                  Main Function                          =
#==========================================================

$ToolVersion="0.01";  # Diag Tool Version , If Change Must Modify Here

printf "\e[33m\n";
print "=================================================\n";
print "         RD Data Tool $ToolVersion For AMD    \n";
print "=================================================\n";

system "cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime"; # Sync Time Zone 2015-12-01 YQ
printf "------------- Graphics Info --------------\n";

&Get_PPID_Order;
&Get_Model_Name ;
&Get_BIOS_Info;
&Get_Mem_Info;
&Get_GPU_MEM_Max_Clock ;

printf "\n------------- Diagnostic Info --------------\n";
&Get_Diag_Version ;
&Get_Diag_Error ;#Need Diag Test Over
&Get_GPU_Max_Temperature ;#Need Diag Test Over
&Get_GFX_VR_Max_Temperature ;#Need Diag Test Over
&Get_SOC_VR_Max_Temperature ;#Need Diag Test Over
&Get_MEM_Max_Temperature ;#Need Diag Test Over
&Get_Diag_Test_Time ;#Need Diag Test Over
&Get_Diag_Test_Data ;#Need Diag Test Over

printf "\n------------- Platform Info --------------\n";
&Get_MB_Info ;
&Get_Platform_os ;
&Get_Diag_Tool_Version();

printf "=================================================\n";
printf "\n\e[0m";


#***********
#Item File
#***********
open (File_Log, ">RD_Data_Item.log");
select File_Log ;
print $item_string."\r\n";

#**************
#Big Data File
#**************
open (File_Log, ">RD_Data.log");
select File_Log ;
print $data_sting."\r\n";


select stdout;

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#                                                        |
#                  Sub Functions                         |
#                  Get RD Tool Version              |
#                                                        |
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++
sub Get_Diag_Tool_Version()
{

        print " Tool_Version\t\t = $ToolVersion\n";
        $item_string=$item_string.' | '."RDToolVersion" ;
        $data_sting = $data_sting.' | '."$ToolVersion" ;


}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#                                                        |
#                  Sub Functions                         |
#                  Get PPID String                       |
#                                                        |
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++
sub Get_PPID_Order()
{
	system './amdvbflash -s 0 ppid.rom >/dev/null';
	$ppidstr = `dd if=./ppid.rom bs=2k 2>/dev/null |strings|grep PPID`;
	@ppid =  split /\#|]/, $ppidstr ; #$ppidnum = ppid number (CTZXXXXXXXXXXx)
    system "rm ppid.rom";
	$ppid = $ppid[1];
	chomp($ppid);

	if ($ppid eq "" )
	{
		$ppid = "TEST00000000001";
	}

	print " PPID\t\t\t = $ppid\n";
	$item_string= "PPID" ;
	$data_sting = $ppid ;
	chomp($ppid);

}


#==========================================================
#                  Get BIOS Info                           =
#==========================================================
sub Get_BIOS_Info()
{

	$asic_serial_num=`./agt -sid |grep -i SerialID`;
	@tmp = split(/=/,$asic_serial_num); # Get ASIC Serial Num 
	chomp($asic_serial_num = $tmp[1]);
	$asic_serial_num=~s/(^\s+|\s+$)//g;
	print " ASIC_Series_ID\t\t = $asic_serial_num\n";
	$item_string = $item_string.' | '."ASIC_Series_ID" ;
	$data_sting = $data_sting.' | '.$asic_serial_num;

	$vbios_string = `./amdvbflash -ai`;
	if ($vbios_string =~ m/Product Name/)
	{
		my @vbios_string_lines = split("\n", $vbios_string);
		my @vbios_string_lines = split("\n", $vbios_string);
		foreach my $vbios_string_line (@vbios_string_lines)
		{
			if($vbios_string_line =~ m/Asic Family/)
			{
				@tmp = split(/:/,$vbios_string_line);	#ASIC
				chomp($tmp_asic = $tmp[1]);
				$tmp_asic=~s/(^\s+|\s+$)//g;#Remove space
				$asic_name= uc($tmp_asic);
				print " ASIC_Name\t\t = $asic_name\n";
				$item_string = $item_string.' | '."ASICName " ;
				$data_sting = $data_sting.' | '.$asic_name ;
			}
			if($vbios_string_line =~ m/[0-F][0-F][0-F][0-F]1002/)	#DID
			{
				#$BIOS_DID = $vbios_string_line;
				$BIOS_DID = substr($&,0,4);		#match string
				print " BIOS_DID\t\t = $BIOS_DID \n" ;
				$asus_log = $asus_log.' | '.$BIOS_DID;		
				$item_string = $item_string.' | '."BIOS_DID" ;
				$data_sting = $data_sting.' | '.$BIOS_DID ;
			}
			if($vbios_string_line =~ m/[0-F][0-F][0-F][0-F]1043/)	#SSID
			{
				#$BIOS_SSID = $vbios_string_line;
				$BIOS_SSID = substr($&,0,4);	#match string
				print " BIOS_SSID\t\t = $BIOS_SSID \n" ;
				$item_string = $item_string.' | '."BIOS_SSID" ;
				$data_sting = $data_sting.' | '.$BIOS_SSID ;
				
			}			
			if($vbios_string_line =~ m/Product Name/) #BIOS Version
			{
				@Bios_ver = split (/:/,$vbios_string_line);
				$BIOS_VER = $Bios_ver[1];
				$BIOS_VER =~s/(^\s+|\s+$)//g;
				print " BIOS_Version\t\t = $BIOS_VER\n";
				$item_string = $item_string.' | '."DiagBIOSVersion" ;
				$data_sting = $data_sting.' | '.$BIOS_VER ;			
			}
			if($vbios_string_line =~ m/Bios Version/)  #BIOS kit
			{
				@Bios_kit = split (/:/,$vbios_string_line);
				$BIOS_KIT = $Bios_kit[1];
				$BIOS_KIT =~s/(^\s+|\s+$)//g;
				print " BIOS_KIT\t\t = $BIOS_KIT\n";
				$item_string = $item_string.' | '."DiagBIOSKit" ;
				$data_sting = $data_sting.' | '.$BIOS_KIT ;			
			}
			if($vbios_string_line =~ m/Bios P/)  #BIOS 115-PN
			{
				@Bios_PN = split (/:/,$vbios_string_line);
				$BIOS_PN = $Bios_PN[1];
				$BIOS_PN =~s/(^\s+|\s+$)//g;
				print " 115_PN\t\t\t = $BIOS_PN\n";
				$item_string = $item_string.' | '."115PN" ;
				$data_sting = $data_sting.' | '.$BIOS_PN ;			
			}
			if($vbios_string_line =~ m/Config File/)
			{
				@config_file = split(/:/,$vbios_string_line);  
				chomp($config_file = $config_file[1]);
				$config_file=~s/(^\s+|\s+$)//g;
				print " BIOS_Config_File\t = $config_file \n" ;
				$item_string = $item_string.' | '."BIOS_Config_File" ;
				$data_sting = $data_sting.' | '.$config_file ;
				
			}
			if($vbios_string_line =~ m/Bios Date/)
			{
				@bios_date = split(/ : /,$vbios_string_line); 
				chomp($bios_date = $bios_date[1]);
				$bios_date=~s/(^\s+|\s+$)//g;
				print " BIOS_Date\t\t = $bios_date \n" ;
				$item_string = $item_string.' | '."BIOS_Date" ;
				$data_sting = $data_sting.' | '.$bios_date ;
				
			}
			
			
		}
	}		  

	$BIOS_build_num=`./agt -biosbuildnum |grep -i "Build Number"`;	# BIOS Build Num
	@Build_Num = split(/:/,$BIOS_build_num);  
	chomp($BIOS_build_num = $Build_Num[1]);
	$BIOS_build_num=~s/(^\s+|\s+$)//g;
	print " BIOS_Build_Num\t\t = $BIOS_build_num\n";
	$item_string = $item_string.' | '."BIOS_Build_Num" ;
	$data_sting = $data_sting.' | '.$BIOS_build_num;


}

#==========================================================
#                  Get Memory Info                           =
#==========================================================

sub Get_Mem_Info()
{
	$memory_info=`./agt -mccfg`;
	my @memory_string_lines = split("\n", $memory_info);
	my @memory_string_lines = split("\n", $memory_info);
	foreach my $memory_string_line (@memory_string_lines)
	{
		if($memory_string_line =~ m/Memory vendor/)
		{
			@mem_vendor = split(/:/,$memory_string_line); 
			chomp($mem_vendor = $mem_vendor[1]);
			$mem_vendor=~s/(^\s+|\s+$)//g;
			print " MEM_Vendor_Type\t = $mem_vendor \n" ;
			$item_string = $item_string.' | '."MEM_Vendor" ;
			$data_sting = $data_sting.' | '.$mem_vendor ;
		}
		if($memory_string_line =~ m/Calculated memory size/)
		{
			@mem_size = split(/:/,$memory_string_line); 
			chomp($mem_size = $mem_size[1]);
			$mem_size=~s/(^\s+|\s+$)//g;
			print " MEM_Size\t\t = $mem_size \n" ;
			$item_string = $item_string.' | '."MEM_Size" ;
			$data_sting = $data_sting.' | '.$mem_size ;
		}
	
	}
	
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
	}
	else{
		$tmp_diag_version="NA";
	}
	print " Diag_Version\t\t = $tmp_diag_version\n";

	$item_string = $item_string.' | '."DiagVersion" ;
	$data_sting = $data_sting.' | '.$tmp_diag_version;		


}

#==========================================================
#                  Get Model Name                         =
#==========================================================
sub Get_Model_Name()
{
	if(-e "FCT_CONF.DAT")
	{
		$Model_Name=`cat FCT_CONF.DAT|grep -i "modelname"`;
        chomp($Model_Name);
		@tmp = split(/=/,$Model_Name);
		$Model_Name= $tmp[1];
		$Model_Name=~s/(^\s+|\s+$)//g;#Remove space
        chop($Model_Name);
	
	}
	else
	{
		`./amdvbflash -s 0 bios.rom >/dev/null`;
		$ppidstr = `dd if=./bios.rom bs=2k 2>/dev/null |strings|grep PPID`;
		@ppidnum =  split /\#|]/, $ppidstr ; 
		chomp($ppidnum[0]);
		$Model_Name = substr($ppidnum[0],4);
		`rm bios.rom`;
	}
	if ($Model_Name eq "")
	{
		$Model_Name="NULL" ;
	}
	print " Model_Name\t\t = $Model_Name\n";
	$item_string = $item_string.' | '."ModelName" ;
	$data_sting = $data_sting.' | '.$Model_Name;
}

#==========================================================
#        Get Diag Max Temperature                         =
#==========================================================
sub Get_GPU_Max_Temperature
{
	if (-e "log.txt" )
	{
		@hot_temp = `cat log.txt|grep -i hotspot|grep -o "max= [0-9]*[0-9]"|grep -o "[0-9]*[0-9]"`; #GPU Max Temperature
	} 
	#$tmp=~m%([\d]+)(\D+)([\d]+)(\D+)([\d]+)(\D+)%g;#mean= ****;max= ****;target= ****
	$TempMax=$hot_temp[0];
	foreach(@hot_temp)
	{
		chomp;
		if($TempMax < $_ ){ $TempMax = $_ ;}
	
	}
	$TempMax=~s/(^\s+|\s+$)//g;#Remove space
	if ($TempMax eq "" )
	{
		$TempMax = -1 ;
	}else{
		$TempMax =int($TempMax);
		}
	print " Hotspot_Max_Temperature = $TempMax\n" ;

	$item_string = $item_string .' | '."HotspotMaxTemperature " ;
	$data_sting = $data_sting.' | '.$TempMax ;


}

sub Get_GFX_VR_Max_Temperature
{
	if (-e "log.txt" )
	{
		@gfx_temp = `cat log.txt|grep -i gfx_vr |grep -o "max= [0-9]*[0-9]"|grep -o "[0-9]*[0-9]"`; #GPU Max Temperature
	} 
	#$tmp=~m%([\d]+)(\D+)([\d]+)(\D+)([\d]+)(\D+)%g;#mean= ****;max= ****;target= ****
	$GFX_TempMax=$gfx_temp[0];
	foreach(@gfx_temp)
	{
		chomp;
		if($GFX_TempMax < $_ ){ $GFX_TempMax = $_ ;}
	
	}
	$GFX_TempMax=~s/(^\s+|\s+$)//g;#Remove space
	if ($GFX_TempMax eq "" )
	{
		$GFX_TempMax = -1 ;
	}else{
		$GFX_TempMax =int($GFX_TempMax);

	}
	print " GFX_VR_Max_Temperature\t = $GFX_TempMax\n" ;
	$item_string = $item_string .' | '."GFX_VR_MaxTemperature " ;
	$data_sting = $data_sting.' | '.$GFX_TempMax ;

	
}

sub Get_SOC_VR_Max_Temperature
{
	if (-e "log.txt" )
	{
		@soc_temp = `cat log.txt|grep -i soc_vr |grep -o "max= [0-9]*[0-9]"|grep -o "[0-9]*[0-9]"`; #GPU Max Temperature
	} 
	#$tmp=~m%([\d]+)(\D+)([\d]+)(\D+)([\d]+)(\D+)%g;#mean= ****;max= ****;target= ****
	$SOC_TempMax=$soc_temp[0];
	foreach(@soc_temp)
	{
		chomp;
		if($SOC_TempMax < $_ ){ $SOC_TempMax = $_ ;}
	
	}
		$SOC_TempMax=~s/(^\s+|\s+$)//g;#Remove space
		if ($SOC_TempMax eq "" )
		{
		$SOC_TempMax = -1 ;
		}else{
			$SOC_TempMax =int($SOC_TempMax);

		}
		print " SOC_VR_Max_Temperature\t = $SOC_TempMax\n" ;

		$item_string = $item_string .' | '."SOC_VR_MaxTemperature " ;
		$data_sting = $data_sting.' | '.$SOC_TempMax ;

	
}


sub Get_MEM_Max_Temperature
{
	if (-e "log.txt" )
	{
		@mem_temp = `cat log.txt|grep -i umc|grep -o "[0-9]*[0-9].[0-9] Deg"|grep -o "[0-9]*[0-9]"`; #GPU Max Temperature
	} 
	#$tmp=~m%([\d]+)(\D+)([\d]+)(\D+)([\d]+)(\D+)%g;#mean= ****;max= ****;target= ****
	$MEMTempMax=$mem_temp[0];
	foreach(@mem_temp)
	{
		chomp;
		if($MEMTempMax < $_ ){ $MEMTempMax = $_ ;}
	
	}
		$MEMTempMax=~s/(^\s+|\s+$)//g;#Remove space
		if ($MEMTempMax eq "" )
		{
		$MEMTempMax = -1 ;
		}else{
			$MEMTempMax =int($MEMTempMax);

		}
	print " MEM_Max_Temperature\t = $MEMTempMax\n" ;

	$item_string = $item_string .' | '."DiagMEMMaxTemperature " ;
	$data_sting = $data_sting.' | '.$MEMTempMax ;

	if ($MEMTempMax != -1)
	{
		@umc = `cat log.txt|grep -n "[0-9].[0-9].[0-9] Deg"|grep $MEMTempMax`;	
	}
	print @umc;
}

#==========================================================
#        Get Diag Test Date and Time                      =
#==========================================================
sub Get_Diag_Test_Data
{
	
	$Server_date = `date +%Y-%m-%d`;
	chomp($Server_date);
	$Server_time = `date +%H:%M:%S`;
	chomp($Server_time);
	print " Date_Time\t\t = $Server_date $Server_time \n";


	$item_string = $item_string.' | '."DateTime" ;
	$data_sting = $data_sting.' | '."$Server_date $Server_time" ;

}

#==========================================================
#        Get Diag TEST Time				                  =
#==========================================================
sub Get_Diag_Test_Time
{
	if (-e "log.txt" )
	{
		@StartTime = `cat log.txt|grep "<*>"|head -1|grep -o "[0-9][0-9]:[0-9][0-9]:[0-9][0-9]"`; # Will List More ,But Only Need First One ! YongQi
	}
	chomp($StartTime=@StartTime[0]);  # Get First One YongQi
	$StartTime=~s/(^\s+|\s+$)//g;#Remove space
	if ($StartTime eq "" )
	{
		$StartTime =-1 ;
		}
	print " Diag_Start_Time\t = $StartTime\n";
	$item_string = $item_string.' | '."DiagStartTime" ;
	$data_sting = $data_sting.' | '.$StartTime ;

	if (-e "log.txt" )
	{
		@EndTime = `cat log.txt|grep "<*>"|tail -1|grep -o "[0-9][0-9]:[0-9][0-9]:[0-9][0-9]"`; # Will List More ,But Only Need First One ! YongQi
	}
	chomp($EndTime=@EndTime[0]);  # Get First One YongQi
	$EndTime=~s/(^\s+|\s+$)//g;#Remove space
	if ($EndTime eq "" )
		{
			$EndTime =-1 ;
		}
	print " Diag_End_Time\t\t = $EndTime\n";
	$item_string = $item_string.' | '."DiagEndTime" ;
	$data_sting = $data_sting.' | '.$EndTime ;

	my @Sitem = split /:/, $StartTime;
	my @Eitem = split /:/, $EndTime;
	$DeltaTime = $Eitem[0] * 3600 + $Eitem[1] * 60 + $Eitem[2] - $Sitem[0] * 3600 - $Sitem[1] * 60 -$Sitem[2];
	if($DeltaTime < 0) {$DeltaTime += 86400;}
	$DeltaTime=~s/(^\s+|\s+$)//g;#Remove space
		if ($DeltaTime eq "" )
		{
		$DeltaTime =-1 ;
		}
	print " Diag_Use_Time\t\t = $DeltaTime Sec\n";
		$item_string = $item_string.' | '."DiagUseTime" ;
		$data_sting = $data_sting.' | '.$DeltaTime ;		


}

#==========================================================
#                  Get Diag Error                         =
#==========================================================
sub Get_Diag_Error
{

	if (-e "errorid.tmp" )
	{
		$ERROR_CODE=`cat errorid.tmp`;
        	chomp($ERROR_CODE);
		if ($ERROR_CODE eq "PASS"|| $ERROR_CODE eq "Pass" ||$ERROR_CODE eq "pass" )
		{
			$STATUS="Pass";
		}else{
			$STATUS="Fail";
		}
		print " Diag_Test_Status\t = $STATUS\n";
		print " Diag_Error_Code\t = $ERROR_CODE   \n";

        	$item_string = $item_string.' | '."DiagTestStatus" ;
        	$data_sting = $data_sting.' | '.$STATUS ;
        	$item_string = $item_string.' | '."DiagErrorCode" ;
        	$data_sting = $data_sting.' | '.$ERROR_CODE ;




	}
	else
	{
		print " Diag_Test_Status\t = Fail\n";
		print " Diag_Error_Code\t = NULL \n";

		$item_string = $item_string.' | '."DiagTestStatus" ;
		$data_sting = $data_sting.' | '."Fail" ;
		$item_string = $item_string.' | '."DiagErrorCode" ;
		$data_sting = $data_sting.' | '."NULL" ;

	}

}




#==========================================================
#                  Get MB Info                            =
#==========================================================
sub Get_MB_Info
{


		#==========================================================
		#                  Get MB Name                            =
		#==========================================================

		$MB_name = `dmidecode -t 2 |grep Name`;
		@tmp = split(/:/,$MB_name); # Get MB Name  
		chomp($MB_name = $tmp[1]);
		$MB_name=~s/(^\s+|\s+$)//g;
		#system "echo Diag_MB_Product_Name=$MB_name >>ECS_Big_Data.log ";
		print " MB_Product_Name\t = $MB_name\n";
        	$item_string = $item_string.' | '."DiagMBProductName" ;
        	$data_sting = $data_sting.' | '."$MB_name" ;



		#==========================================================
		#                  Get System BIOS Version                =
		#==========================================================
		$MB_System_BIOS = `dmidecode -t 0 |grep Version`;
		@tmp = split(/:/,$MB_System_BIOS); # Get System BIOS Verison  
		chomp($MB_System_BIOS = $tmp[1]);
		$MB_System_BIOS=~s/(^\s+|\s+$)//g;
		print " System_BIOS_Version\t = $MB_System_BIOS\n";
        	$item_string = $item_string.' | '."DiagSystemBIOSVersion" ;
        	$data_sting = $data_sting.' | '.$MB_System_BIOS ;

		#==========================================================
		#                  Get CPU Info                           =
		#==========================================================
		$CPU_Info = `dmidecode -t 4 |grep Version`;
		@tmp = split(/:/,$CPU_Info); # Get CPU Info
		chomp($CPU_Info = $tmp[1]);
		$CPU_Info=~s/(^\s+|\s+$)//g;
		print " CPU_Info\t\t = $CPU_Info\n";
        	$item_string = $item_string.' | '."DiagCPUInfo" ;
        	$data_sting = $data_sting.' | '.$CPU_Info ;


		#==========================================================
		#                  Get System Memory Size                 =
		#==========================================================

		@tmp = `dmidecode -t 17 |grep Size|grep -o "[0-9]*[0-9]"`;#Get Memory Size  	
		foreach (@tmp) 
		{
		    chomp;
		    $TotalMemorySize += $_; #Add All Memory 
	        }		
		print " System_Memory_Size\t = $TotalMemorySize\n";
        	$item_string = $item_string.' | '."DiagSystemMemorySize" ;
        	$data_sting = $data_sting.' | '.$TotalMemorySize;

}


#==========================================================
#             Get GPU/MEM MaxClock                 =
#==========================================================
sub Get_GPU_MEM_Max_Clock()
{
	$tmp = `./agt -pplist=short |grep -i HIGH`;

	$tmp=~m%([\d]+)(\D+)([\d]+)(\D+)([\d]+)(\D+)%g;#SOC **** GFX **** MEM ****
	#printf "\e[33mtmp=$tmp\e[0m\n";
	print " SOC_MaxClock\t\t = $1 Mhz\n";
	print " GFX_MaxClock\t\t = $3 Mhz\n";
	print " MEM_MaxClock\t\t = $5 Mhz\n";

	$t1=$1; #SOCMaxClock
	$t3=$3; #DiagGPUMaxClock
	$t5=$5; #DiagMemoryMaxClock

	$t1=~s/(^\s+|\s+$)//g;#Remove space
	if ($t1 eq "" )
	{
		$t1 =-1 ;
	}
	$t3=~s/(^\s+|\s+$)//g;#Remove space
	if ($t3 eq "" )
	{
		$t3 =-1 ;
	}
	$t5=~s/(^\s+|\s+$)//g;#Remove space
	if ($t5 eq "" )
	{
		$t5 =-1 ;
	}

	$item_string = $item_string.' | '."SOCMaxClock".' | '."GFXMaxClock".' | '."MEMMaxClock" ;
	$data_sting = $data_sting.' | '.$t1.' | '.$t3.' | '.$t5;

}

#==========================================================
#                  Get Platform info                      =
#==========================================================
sub Get_Platform_os()
{

		$Linux_OS = `lsb_release -d`;#|grep Description 2>/dev/null`;
        	chomp($Linux_OS);
		@tt = split (/:/,$Linux_OS);
		$Linux_OS = $tt[1];
		$Linux_OS=~s/(^\s+|\s+$)//g; #Remove space
		print " Platform\t\t = $Linux_OS\n";
        	$item_string = $item_string.' | '."Platform" ;
        	$data_sting = $data_sting.' | '."$Linux_OS";
}



