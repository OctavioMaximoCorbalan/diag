./tserverlite -d=1 -cf=tserver_memtune.cf -test=umc321.25 -df_ecc_config_mode=gncm_noalloc -pm4rb=system -pm4ib=system -pm4rbsize=0x20000
./tserverlite -d=1 -cf=tserver_memtune.cf -test=umc404.14 -df_ecc_config_mode=gncm_noalloc -pm4rb=system -pm4ib=system -pm4rbsize=0x20000
./tserverlite -d=1 -cf=tserver_memtune.cf -test=umc56.155 -df_ecc_config_mode=gncm_noalloc -pm4rb=system -pm4ib=system -pm4rbsize=0x20000
./tserverlite -d=1 -cf=tserver_memtune.cf -test=umc56.154 -df_ecc_config_mode=gncm_noalloc -pm4rb=system -pm4ib=system -pm4rbsize=0x20000
./tserverlite -d=1 -cf=tserver_memtune.cf -test=std4.6 -df_ecc_config_mode=gncm_noalloc -maxframes=2000 -surfacecrcmode=shader -maxtime=0 -texture_shader_tile_copy -tglEnableSCBinning=0 -tglDisableBinningUseLegacySC=1
./tserverlite -d=1 -cf=tserver_memtune.cf -test=std4.33 -df_ecc_config_mode=gncm_noalloc -maxframes=2000 -surfacecrcmode=shader -maxtime=0 -texture_shader_tile_copy -tglEnableSCBinning=0 -tglDisableBinningUseLegacySC=1 -fiwc
