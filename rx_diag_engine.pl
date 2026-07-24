#!/usr/bin/perl
use strict;
use warnings;
use File::Copy;
use File::Path qw(make_path);
use Getopt::Long;
use POSIX qw(strftime);

my $mode = '';
my $exit_code = 0;
GetOptions(
    'validate' => sub { $mode = 'validate' },
    'parse=s'  => sub { $mode = 'parse'; $exit_code = shift },
) or die "Uso: perl rx_diag_engine.pl --validate | --parse <exit_code>\n";

my $log_dir = 'test_logs';
my $profile_dst = 'FCT_CONF.DAT';

# ===================================================================
# PILAR 1: RUTINAS DE VALIDACIÓN DE HARDWARE (Rescatadas de Asus)
# ===================================================================

sub read_profile_value {
    my ($key) = @_;
    return '' unless -f $profile_dst;
    open my $fh, '<', $profile_dst or return '';
    while (my $line = <$fh>) {
        chomp $line;
        if ($line =~ /^$key\s+(.+)$/) {
            close $fh;
            my $val = $1;
            $val =~ s/^\s+|\s+$//g;
            return $val;
        }
    }
    close $fh;
    return '';
}

sub FAN_Test {
    my $fantest = read_profile_value('FANTEST');
    my $fan_script = '';

    if (!defined $fantest || $fantest eq '' || $fantest eq '0') {
        print "FAN_TEST\t = SKIP (FANTEST=0)\n";
        return 0;
    }

    if (-x './FANTEST_LINUX-V12') {
        $fan_script = './FANTEST_LINUX-V12';
    } elsif (-x './gpio-b-fan') {
        $fan_script = './gpio-b-fan';
    } else {
        print "\e[31m [FAIL] No se encontró un script de fan test válido. \e[0m\n";
        return 1;
    }

    print "FAN_TEST\t = RUN ($fan_script)\n";
    my $gpio_rc = system('./gpio-b-fan');
    my $fan_rc = system($fan_script);

    if ($gpio_rc != 0 || $fan_rc != 0) {
        print "\e[31m [FAIL] FAN test falló. \e[0m\n";
        return 1;
    }

    print "\e[32m [PASS] FAN test superado. \e[0m\n";
    return 0;
}

sub validate_hardware {
    print "\n\e[33m===============================================\e[0m\n";
    print "      VALIDACIÓN DE HARDWARE NAVI 23         \n";
    print "\e[33m===============================================\e[0m\n";

    my $ok = 1;
    my $expected_did = read_profile_value('DID');
    my $expected_mem = read_profile_value('MEM_Size');
    my $expected_vendor = read_profile_value('MEM_Vendor_Type');
    my $expected_link = read_profile_value('LINKWIDTH');

    # 1. Check DID (Extraído de P_OQC_PPID_MCU.pl)
    my $did_detect = `./amdvbflash -ai |grep -o [0-F][0-F][0-F][0-F]1002 |cut -c 1-4`;
    chomp($did_detect);
    print "BIOS_DID\t = $did_detect \n";
    if ($did_detect ne $expected_did) {
        print "\e[31m [FAIL] Check DID Mismatch! \e[0m\n";
        $ok = 0;
    }

    # 2. Check MEM & Vendor (Extraído de P_OQC_PPID_MCU.pl)
    my $memory_info = `./agt -mccfg`;
    my $mem_vendor = "UNKNOWN";
    my $mem_size = "UNKNOWN";
    
    my @mem_lines = split("\n", $memory_info);
    foreach my $line (@mem_lines) {
        if($line =~ m/Memory vendor/) {
            my @parts = split(/:/, $line); 
            $mem_vendor = $parts[1];
            $mem_vendor =~ s/^\s+|\s+$//g;
            print "MEM_Vendor_Type\t = $mem_vendor \n";
            if ($mem_vendor ne $expected_vendor) {
                print "\e[31m [FAIL] Vendor no coincide con el perfil ($expected_vendor) \e[0m\n";
                $ok = 0;
            }
        }
        if($line =~ m/Calculated memory size/) {
            my @parts = split(/:/, $line); 
            $mem_size = $parts[1];
            $mem_size =~ s/^\s+|\s+$//g;
            print "MEM_CALC_size\t = $mem_size \n";
            if ($mem_size ne $expected_mem) {
                print "\e[31m [FAIL] Tamaño VRAM Incorrecto. Esperado: $expected_mem \e[0m\n";
                $ok = 0;
            }
        }
    }

    # 3. Check PCIe Linkwidth (Extraído de P_OQC_PPID_MCU.pl)
    my $link_detect = `./agt -pciestatus |grep -oi 'x[1-9]\\{1,2\\}'`;
    chomp($link_detect);
    $link_detect =~ s/x//ig; # Limpiar la 'x'
    print "LINKWIDTH_Value\t = x$link_detect \n";
    if ($link_detect ne $expected_link) {
        print "\e[31m [FAIL] LinkWidth no es x$expected_link \e[0m\n";
        $ok = 0;
    }

    if ($ok) {
        my $fan_rc = FAN_Test();
        if ($fan_rc != 0) {
            return 1;
        }
        print "\e[32m[PASS] Validación superada. Iniciando diagnóstico...\e[0m\n";
        return 0;
    }
    return 1;
}


# ===================================================================
# PILAR 2: PARSER DE RESULTADOS Y TEMPERATURAS (Rescatado de Asus)
# ===================================================================

sub get_temperatures {
    # Extraído de Data_For_RD_AMD.pl
    my %temps = ( Hotspot => -1, GFX_VR => -1, SOC_VR => -1, MEM => -1 );
    return %temps unless -e "log.txt";

    my @hot_temp = `cat log.txt | grep -i hotspot | grep -o "max= [0-9]*[0-9]" | grep -o "[0-9]*[0-9]"`;
    $temps{Hotspot} = (sort { $b <=> $a } map { chomp; $_ + 0 } @hot_temp)[0] || "N/A";

    my @gfx_temp = `cat log.txt | grep -i gfx_vr | grep -o "max= [0-9]*[0-9]" | grep -o "[0-9]*[0-9]"`;
    $temps{GFX_VR} = (sort { $b <=> $a } map { chomp; $_ + 0 } @gfx_temp)[0] || "N/A";

    my @soc_temp = `cat log.txt | grep -i soc_vr | grep -o "max= [0-9]*[0-9]" | grep -o "[0-9]*[0-9]"`;
    $temps{SOC_VR} = (sort { $b <=> $a } map { chomp; $_ + 0 } @soc_temp)[0] || "N/A";

    my @mem_temp = `cat log.txt | grep -i umc | grep -o "[0-9]*[0-9].[0-9] Deg" | grep -o "[0-9]*[0-9]"`;
    $temps{MEM} = (sort { $b <=> $a } map { chomp; $_ + 0 } @mem_temp)[0] || "N/A";

    return %temps;
}

sub read_text_file {
    my ($path) = @_;
    return '' unless defined $path && -f $path;
    open my $fh, '<', $path or return '';
    local $/;
    my $text = <$fh>;
    close $fh;
    return $text || '';
}

sub normalize_channel_label {
    my ($label) = @_;
    return '' unless defined $label;
    $label =~ s/^\s+|\s+$//g;
    $label =~ s/^CH_//i;
    $label =~ s/^CHANNEL_?//i;
    $label =~ s/[^A-Za-z0-9]+//g;
    return '' unless $label;

    my $upper = uc($label);
    return $upper if $upper =~ /^(A0|A1|B0|B1|C0|C1|D0|D1)$/;
    if ($upper =~ /^CH([0-7])$/) {
        my %map = (0 => 'A0', 1 => 'A1', 2 => 'B0', 3 => 'B1', 4 => 'C0', 5 => 'C1', 6 => 'D0', 7 => 'D1');
        return $map{$1};
    }
    return '';
}

sub channel_subpart {
    my ($channel) = @_;
    my %map = (A0 => 'Ch0', A1 => 'Ch1', B0 => 'Ch2', B1 => 'Ch3', C0 => 'Ch4', C1 => 'Ch5', D0 => 'Ch6', D1 => 'Ch7');
    return $map{$channel} || $channel;
}

sub extract_channel_stats_from_log {
    my ($text) = @_;
    my %stats;
    return \%stats unless defined $text && $text ne '';

    for my $line (split /\n/, $text) {
        my $channel = '';
        if ($line =~ /\b(?:ch|channel)\s*([0-9]+)\b/i) {
            $channel = normalize_channel_label('Ch' . $1);
        } elsif ($line =~ /\b([A-D][0-9])\b/) {
            $channel = normalize_channel_label($1);
        }
        next unless $channel;

        my ($read_err) = $line =~ /\b(?:read|reads?)\s*(?:error|errors?)\s*[:=]?\s*([0-9]+)/i;
        my ($write_err) = $line =~ /\b(?:write|writes?)\s*(?:error|errors?)\s*[:=]?\s*([0-9]+)/i;
        my ($edc_err) = $line =~ /\b(?:edc|parity|dq)\s*(?:error|errors?)\s*[:=]?\s*([0-9]+)/i;
        if (!defined $read_err && $line =~ /\b(?:read|reads?)\b.*?([0-9]+)\s*,\s*.*?edc/i) {
            ($read_err) = $line =~ /\b(?:read|reads?)\b.*?([0-9]+)\s*,\s*.*?edc/i;
        }
        if (!defined $write_err && $line =~ /\b(?:write|writes?)\b.*?([0-9]+)\s*,\s*.*?edc/i) {
            ($write_err) = $line =~ /\b(?:write|writes?)\b.*?([0-9]+)\s*,\s*.*?edc/i;
        }
        if (!defined $edc_err && $line =~ /\b(?:edc|parity|dq)\b.*?([0-9]+)/i) {
            ($edc_err) = $line =~ /\b(?:edc|parity|dq)\b.*?([0-9]+)/i;
        }

        $stats{$channel}{read_errors} += 0 + ($read_err || 0);
        $stats{$channel}{write_errors} += 0 + ($write_err || 0);
        $stats{$channel}{edc_errors} += 0 + ($edc_err || 0);
    }

    return \%stats;
}

sub extract_margin_state_from_csv {
    my ($text) = @_;
    my %margins;
    return \%margins unless defined $text && $text ne '';

    my @lines = split /\n/, $text;
    my @channels;
    my $header_found = 0;

    for my $line (@lines) {
        next unless defined $line;
        my @cells = map { s/^\s+|\s+$//gr } split /,/, $line;
        next unless @cells > 1;

        if (!$header_found) {
            for my $cell (@cells) {
                next unless $cell;
                my $normalized = normalize_channel_label($cell);
                if ($normalized) {
                    push @channels, $normalized;
                }
            }
            if (@channels) {
                $header_found = 1;
            }
            next;
        }

        my $row_name = $cells[0] || '';
        next unless $row_name =~ /^(Default|Phase|Vref|Read|Write)/i;

        for my $idx (0 .. $#channels) {
            my $channel = $channels[$idx];
            next unless $channel =~ /^(A0|A1|B0|B1)$/;
            my $value = $cells[$idx + 1] || '';
            $value =~ s/^\s+|\s+$//g;
            next unless defined $value && $value ne '';
            $margins{$channel} = $value; 
        }
    }

    return \%margins;
}

sub ShowPass {
    # Extraído literalmente de los scripts de ASUS
    printf  "\e[32m\n";
    print "PPPPPPPP          AAA            SSSSS            SSSSS     \n";
    print "PPPPPPPPPP       AAAAA         SSSSSSSSSS       SSSSSSSSSS  \n";
    print "PPP     PPP     AAA AAA       SSS     SSSS     SSS     SSSS \n";
    print "PPP     PPP    AAA   AAA      SSS              SSS          \n";
    print "PPPPPPPPPP    AAA     AAA      SSS              SSS         \n";
    print "PPPPPPPP      AAA     AAA        SSSS             SSSS      \n";
    print "PPP           AAA     AAA          SSSS             SSSS    \n";
    print "PPP           AAAAAAAAAAA            SSSS             SSSS  \n";
    print "PPP           AAAAAAAAAAA              SSS              SSS \n";
    print "PPP           AAA     AAA     SSSS     SSS     SSSS     SSS \n";
    print "PPP           AAA     AAA      SSSSSSSSSS       SSSSSSSSSS  \n";
    print "PPP           AAA     AAA         SSSSS            SSSSS    \n";
    printf  "\e[0m\n\n";
}

sub ShowFail {
    # Extraído literalmente de los scripts de ASUS
    printf  "\e[31m\n";
    print "FFFFFFFFF         AAA         IIIIIIIII     LLL        \n";
    print "FFFFFFFFF        AAAAA        IIIIIIIII     LLL        \n";
    print "FFF             AAA AAA          III        LLL        \n";
    print "FFF            AAA   AAA         III        LLL        \n";
    print "FFF           AAA     AAA        III        LLL        \n";
    print "FFFFFFFF      AAA     AAA        III        LLL        \n";
    print "FFFFFFFF      AAA     AAA        III        LLL        \n";
    print "FFF           AAAAAAAAAAA        III        LLL        \n";
    print "FFF           AAAAAAAAAAA        III        LLL        \n";
    print "FFF           AAA     AAA        III        LLL        \n";
    print "FFF           AAA     AAA     IIIIIIIII     LLLLLLLLLLL\n";
    print "FFF           AAA     AAA     IIIIIIIII     LLLLLLLLLLL\n";
    printf "\n\n\e[0m";
}

sub parse_results {
    my ($exit_code) = @_;
    my $errorid = '';
    if (-e 'errorid.tmp') {
        $errorid = `cat errorid.tmp`;
        chomp($errorid);
    }

    # Definir el veredicto
    my $status = "FAIL";
    if ($exit_code == 0 && $errorid =~ /PASS/i) {
        $status = "PASS";
    }

    # Leer temperaturas
    my %temps = get_temperatures();

    # Estado de ventiladores
    my $fan_status = 'SKIP';
    my $fantest = read_profile_value('FANTEST');
    if (defined $fantest && $fantest ne '' && $fantest ne '0') {
        my $fan_rc = system('./gpio-b-fan >/dev/null 2>&1');
        my $fan_script_rc = 0;
        if (-x './FANTEST_LINUX-V12') {
            $fan_script_rc = system('./FANTEST_LINUX-V12 >/dev/null 2>&1');
        }
        $fan_status = ($fan_rc == 0 && $fan_script_rc == 0) ? 'PASS' : 'FAIL';
    }

    my $log_text = read_text_file('log.txt');
    my $margin_text = read_text_file('MarginResult.csv');
    my $stats = extract_channel_stats_from_log($log_text);
    my $margins = extract_margin_state_from_csv($margin_text);

    my @channel_order = qw(A0 A1 B0 B1);
    my @table_lines;
    push @table_lines, "------------------------------------------------------------------------";
    push @table_lines, " EVALUACIÓN DE CANALES VRAM (Topología 128-bit):";
    push @table_lines, "------------------------------------------------------------------------";
    push @table_lines, " CANAL / SUBPART | ESTADO | READ ERRORS | WRITE ERRORS | EDC / PARITY";
    push @table_lines, "------------------------------------------------------------------------";

    my $channel_fail = 0;
    my @margin_notes;
    for my $channel (@channel_order) {
        my $read_err = $stats->{$channel}{read_errors} || 0;
        my $write_err = $stats->{$channel}{write_errors} || 0;
        my $edc_err = $stats->{$channel}{edc_errors} || 0;
        my $margin_value = $margins->{$channel};
        my $state = 'PASS';
        if ($read_err > 0 || $write_err > 0 || $edc_err > 0) {
            $state = 'FAIL';
            $channel_fail = 1;
        }
        if (defined $margin_value && $margin_value ne '' && $margin_value =~ /^NA$/i) {
            $state = 'FAIL';
            $channel_fail = 1;
            push @margin_notes, "$channel -> margen NA";
        } elsif (defined $margin_value && $margin_value ne '' && $margin_value =~ /^-\d+(?:\.\d+)?$/) {
            $state = 'FAIL';
            $channel_fail = 1;
            push @margin_notes, "$channel -> margen $margin_value";
        }

        push @table_lines, sprintf(
            " Canal %-10s | %-5s | %12d | %13d | %12d",
            "$channel (" . channel_subpart($channel) . ")",
            $state,
            $read_err,
            $write_err,
            $edc_err
        );
    }

    push @table_lines, "------------------------------------------------------------------------";
    if (@margin_notes) {
        push @table_lines, " Notas de márgenes: " . join('; ', @margin_notes);
    } else {
        push @table_lines, " Notas de márgenes: sin anomalías detectadas";
    }
    push @table_lines, "------------------------------------------------------------------------";

    if ($channel_fail) {
        $status = 'FAIL';
    }

    # Armar reporte
    my @summary;
    push @summary, "==========================================================";
    push @summary, "                  REPORTE DE DIAGNÓSTICO                  ";
    push @summary, "==========================================================";
    push @summary, " ESTADO TSERVER : " . ($exit_code == 0 ? "0 (Sin caída de software)" : $exit_code);
    push @summary, " CÓDIGO ERRORID : " . ($errorid || "NO GENERADO");
    push @summary, "----------------------------------------------------------";
    push @summary, " LECTURA DE TEMPERATURAS MÁXIMAS DURANTE EL TEST:";
    push @summary, "   Hotspot   : " . $temps{Hotspot} . " °C";
    push @summary, "   GFX VR    : " . $temps{GFX_VR} . " °C";
    push @summary, "   SOC VR    : " . $temps{SOC_VR} . " °C";
    push @summary, "   VRAM (UMC): " . $temps{MEM} . " °C";
    push @summary, "   Ventiladores: $fan_status";
    push @summary, "----------------------------------------------------------";
    push @summary, @table_lines;
    push @summary, "==========================================================";

    print join("\n", @summary), "\n";

    if ($status eq "PASS") {
        ShowPass();
    } else {
        ShowFail();
    }

    # Guardado de log persistente
    my $stamp = strftime('%Y%m%d_%H%M%S', localtime);
    make_path($log_dir) unless -d $log_dir;
    my $out_file = "$log_dir/[$status]_NAVI23_${stamp}.log";
    open my $out_fh, '>', $out_file or die "No se pudo escribir $out_file\n";
    print {$out_fh} join("\n", @summary), "\n";
    close $out_fh;
    print "\n[LOG] Reporte guardado en $out_file\n";
}

# ===================================================================
# EJECUCIÓN DEL MOTOR
# ===================================================================

if ($mode eq 'validate') {
    exit validate_hardware();
} elsif ($mode eq 'parse') {
    parse_results($exit_code);
    exit 0;
} else {
    die "Debe especificar --validate o --parse <exit_code>\n";
}