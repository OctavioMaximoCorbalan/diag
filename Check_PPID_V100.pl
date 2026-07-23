#!/usr/bin/perl
#2016/06/13 Yong-qi
#For New Linux System 14.04.1
#Flash PPID string for TSD. update by Jane . 2017/08/28
#Check if PPID exists. update by Jane . 2017/09/27
#update pn128_TSD, erase old PPIDinfo then add new ppidinfo.
#2019-06-11  Check PPID

system "clear";
printf "\e[32m";
printf "===============================================\n";
printf "=        Check PPID Tool For TSD              =\n";
printf "=         Rev1.00        2019-06-11           =\n";
printf "===============================================\n";
printf "\n\e[0m";

system "rm -f ppid.txt";
system "rm -f Check_PPID_LOG.log";

#$pn128 = "pn128_TSD";
#if (!( -e $pn128 ))
#{
#	print "Can't Find File pn128_TSD , Please Double Check . \n\n";
#        $Test_flag = 110 ;
#        &ShowFail(); 
#}

$flashtool = "./atiflash";
if (!( -e $flashtool ))
{
	print "Can't Find File atiflash , Please Double Check . \n\n";
        $Test_flag = 110 ;
        &ShowFail(); 

}
	
open PPID_LOG ,">./Check_PPID_LOG.log";
print PPID_LOG  `date`;
close PPID_LOG;

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
printf "\n\e[0m";



if ( $ppidnum[1] eq "" ) 
{
	print "\033[31mCan't Find BIOS ROM PPID Strings \033[0m\n\n";
	open PPID_LOG ,">>./Check_PPID_LOG.log";
	print PPID_LOG "Can't find BIOS PPID\nFail\n";
	close PPID_LOG;
        &ShowFail(); 
	exit 110;		
}

else{
	
	open PPID_LOG ,">>./Check_PPID_LOG.log";
	print PPID_LOG "BIOS's PPID :$ppidnum[1]\n";
	close PPID_LOG;
	printf "\n\n";
	printf "----------------------------------------\n";
	printf  "Please Input/Scan Card's PPID Strings:\n";
	printf "----------------------------------------\n";
#	printf "\e[1m\e[32mInput/Scan PPID :\e[0m";
	printf "\e[32mInput/Scan PPID :\e[0m";
	chomp($ppidstring=<STDIN>);
	$pid_len = length($ppidstring);
#	$pid_value=substr($ppidstring,10,1);

    if($pid_len == 15  )
     {
       	print "SFIS Scan String=".$ppidstring."\n" ;
       	print "PPID length=".length($ppidstring)."\n";

     }
     else 
     {
       	print "\n\n\nPPID Scan String=".$ppidstring."\n" ;
       	print "PPID length=".length($ppidstring)."\n";
       	printf "\e[31mPPID Must be 15 bits\e[0m \n";
	exit 110;	
     }
}


open PPID_LOG ,">>./Check_PPID_LOG.log";
print PPID_LOG "Card's PPID :$ppidstring\n";

close PPID_LOG;

chomp($datappid);
print "\n\n==============================\n";
print "BIOS's PPID=$ppidnum[1]\n";
print "Card's PPID=$ppidstring\n";
print "==============================\n\n";


if ($ppidnum[1] eq $ppidstring )
{
	print "\033[32mCheck PPID PASS !\033[0m\n\n";
	open PPID_LOG ,">>./Check_PPID_LOG.log";
	print PPID_LOG "\nPass\n";
	close PPID_LOG ;
	&ShowPass();
   	}
else
{
	print "\033[31mCheck PPID Fail !\033[0m\n\n\n\n\n";
	open PPID_LOG ,">>./Check_PPID_LOG.log";
	print PPID_LOG "\nFail\n";
	close PPID_LOG ;
	&ShowFail();
	exit 110 ;
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
