#!/usr/bin/perl
# 2016/06/13 Yong-qi
#For New Linux System 14.04.1
#Flash PPID string for TSD. update by Jane . 2017/08/28
#Check if PPID exists. update by Jane . 2017/09/27
#update pn128_TSD, erase old PPIDinfo then add new ppidinfo.

system "clear";
printf "\e[32m";
printf "===============================================\n";
printf "=       Update PPID Tool For TSD              =\n";
printf "=         Rev1.30        2017-10-18           =\n";
printf "===============================================\n";
printf "\n\e[0m";

system "rm -f ppid.txt";
system "rm -f org.rom";

$pn128 = "pn128_TSD";
if (!( -e $pn128 ))
{
	print "Can't Find File pn128_TSD , Please Double Check . \n\n";
        $Test_flag = 110 ;
        &ShowFail(); 

}

$flashtool = "./atiflash";
if (!( -e $flashtool ))
{
	print "Can't Find File atiflash , Please Double Check . \n\n";
        $Test_flag = 110 ;
        &ShowFail(); 

}

#=======================================================
#                      CHECK PPID
#=======================================================
	system `./atiflash -s 0 ppid.rom >/dev/null`;
	$ppidstr = `dd if=./ppid.rom bs=2k 2>/dev/null |strings|grep PPID`;
	@ppidnum =  split /\#|]/, $ppidstr ; #$ppidnum = ppid number (CTZXXXXXXXXXXx)
	chomp($ppidnum[1]);
	system `rm ppid.rom`;
	$modelname = substr ($ppidnum[0],4);

printf "\e[32m";
	printf "\n------------------------------------------\n";
	printf "Model Name = $modelname\n\n";
	printf "BIOS PPID = $ppidnum[1]\n";
	printf "------------------------------------------\n";
printf "\n\n\e[0m";


	if ( $ppidnum[1] eq "" ) 
	{
	   print "\033[31mCan't Find BIOS ROM PPID Strings \033[0m\n\n";
	}

	else{
	  print "Press \e[32m <y> \e[0m if you want to update PPIDinfo:  ";
	  $flag = <STDIN>; 
	  print"\n";
	#  print $flag;
	  chomp ($flag);
	}
	
	
	if (( $ppidnum[1] eq "" ) || ( $flag eq 'y') || ( $flag eq 'Y'))
	{
	   print "\033[31mWill update PPID Strings !\033[0m\n";

#=======================================================
#                      UPDATE PPID
#=======================================================

while($pid_len != 15)
  {
    printf "------------------------------------\n";
    printf  "Please Input Model Name Strings:\n";
    printf "------------------------------------\n";
    printf "\e[1m\e[32mInput Model Name :\e[0m";
    chomp($mnamestring=<STDIN>);
    $mname_len = length($mnamestring);
#    $pid_value=substr($ppidstring,10,1);
#    print "$mname_len\n";

    if($mname_len <= 20  )
     {
       	print "Model Name String=\e[32m".$mnamestring."\e[0m\n" ;
       	print "Model Name length=\e[32m".length($mnamestring)."\e[0m\n";

        open  PPID_DAT ,">./ppid.txt";
	print PPID_DAT  "PPID$mnamestring\#";
        close PPID_DAT ;

     }
     else 
     {
       	print "\n\n\nModel Name String=".$mnamestring."\n" ;
       	print "Model Name length=".length($mnamestring)."\n";
       	printf "\e[31mModel Name length Must be LESS THAN 20 bytes\e[0m \n";
	exit 110;
     }


	printf "\n\n";
	printf "------------------------------------\n";
	printf  "Please Input\Scan PPID Strings:\n";
	printf "------------------------------------\n";
	printf "\e[1m\e[32mInput\Scan PPID :\e[0m";
	chomp($ppidstring=<STDIN>);
	$pid_len = length($ppidstring);
#	$pid_value=substr($ppidstring,10,1);

    if($pid_len == 15  )
     {
       	print "SFIS Scan String=\e[32m".$ppidstring."\e[0m\n" ;
       	print "PPID length=\e[32m".length($ppidstring)."\e[0m\n";

        open  PPID_DAT ,">>./ppid.txt";
	print PPID_DAT  $ppidstring ;
        close PPID_DAT ;

     }
     else 
     {
       	print "\n\n\nPPID Scan String=".$ppidstring."\n" ;
       	print "PPID length=".length($ppidstring)."\n";
       	printf "\e[31mPPID Must be 15 bits\e[0m \n";
	exit 110;	
     }
}
	printf "\n\n\e[32mPlease double check the info, will flash immediately! \nPlease press the ENTER.\e[0m\n";
	$update=<STDIN>;

	printf "\n\n";
	system "cat ppid.txt\n";
#	sleep 3;
	system "./pn128_TSD";
	system "./atiflash -p 0 org.rom -f";
	if ( $? ne 0 )  #update bios fail !
	{
	  printf "\e[31mUpdate BIOS  Fail !! Try again ...\n\n\e[0m";
	  &ShowFail();
		}

	
	}

sub ShowPass()
{
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
{   printf  "\e[31m\n";
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

    printf "\n\n\e[0m";
    exit 110 ;
}
