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

my $root = '.';
my $profile_src = 'XFX6650XT_CONF_MOD.DAT';
my $profile_dst = 'FCT_CONF.DAT';
my $log_dir = 'test_logs';
my $serial = 'UNKNOWN';

sub run_cmd {
    my ($cmd) = @_;
    my $out = qx/$cmd 2>&1/;
    return $out;
}

sub read_profile_value {
    my ($key) = @_;
    return '' unless -f $profile_dst;
    open my $fh, '<', $profile_dst or return '';
    while (my $line = <$fh>) {
        chomp $line;
        if ($line =~ /^$key\s+(.+)$/) {
            close $fh;
            return $1;
        }
    }
    close $fh;
    return '';
}

sub detect_device_id {
    my $did = '';
    my $agt = run_cmd('./agt -sid');
    if ($agt =~ /DeviceID\s*[:=]\s*([0-9A-Fa-f]+)/) {
        $did = uc($1);
    }
    return $did;
}

sub detect_mem_info {
    my $mccfg = run_cmd('./agt -mccfg');
    my $vendor = 'UNKNOWN';
    my $size = 'UNKNOWN';
    if ($mccfg =~ /Memory vendor\s*[:=]\s*(.+)/i) {
        $vendor = $1;
        $vendor =~ s/\s+$//;
    }
    if ($mccfg =~ /Calculated memory size\s*[:=]\s*([0-9]+)\s*MB/i) {
        $size = $1;
    }
    return ($vendor, $size);
}

sub detect_pci_width {
    my $pci = run_cmd('./agt -mccfg');
    my $width = 'UNKNOWN';
    if ($pci =~ /PCIe\s+([A-Za-z0-9\s]+x[0-9]+)/i) {
        $width = $1;
    } elsif ($pci =~ /PCIE\s+([A-Za-z0-9\s]+x[0-9]+)/i) {
        $width = $1;
    }
    return $width;
}

sub validate_hardware {
    my $did = detect_device_id();
    my ($vendor, $size) = detect_mem_info();
    my $width = detect_pci_width();
    my $chip = read_profile_value('GPU_CHIP');
    my $model = read_profile_value('MODELNAME');

    print "\n[VALIDATION] Checking hardware state...\n";
    print "  Model      : $model\n";
    print "  Device ID  : $did\n";
    print "  Chip       : $chip\n";
    print "  VRAM       : $size MB\n";
    print "  Vendor     : $vendor\n";
    print "  PCIe Width : $width\n";

    my $ok = 1;
    if ($did ne '73EF') {
        print "[FAIL] Unexpected Device ID. Expected 73EF.\n";
        $ok = 0;
    }
    if ($size ne '' && $size !~ /^8192$/) {
        print "[FAIL] Unexpected VRAM size. Expected ~8192MB.\n";
        $ok = 0;
    }
    if ($chip ne 'NAVI23') {
        print "[FAIL] Unexpected GPU chip profile. Expected NAVI23.\n";
        $ok = 0;
    }
    if ($ok) {
        print "[PASS] Hardware validation passed.\n";
        return 0;
    }
    print "[FAIL] Hardware validation failed.\n";
    return 1;
}

sub parse_result_file {
    my ($path) = @_;
    return '' unless -f $path;
    open my $fh, '<', $path or return '';
    local $/;
    my $data = <$fh>;
    close $fh;
    return $data;
}

sub extract_channel_summary {
    my $text = shift || '';
    my @lines = split /\n/, $text;
    my @summary;
    for my $line (@lines) {
        if ($line =~ /([A-Za-z]+\s*\d+[^\n]*)/ && $line =~ /(PASS|FAIL|ERROR|DQ|parity|channel)/i) {
            push @summary, $line;
        }
    }
    return @summary;
}

sub render_banner {
    my ($state, $title) = @_;
    my $pad = $state eq 'PASS' ? 'GREEN' : 'RED';
    my $line = '=' x 72;
    my $text = $state eq 'PASS' ? 'PASS' : 'FAIL';
    return join("\n",
        $line,
        "                 $title",
        $line,
        "",
        "  $text",
        "",
        $line,
    );
}

sub parse_results {
    my ($exit_code) = @_;
    my $errorid = parse_result_file('errorid.tmp');
    my $margin = parse_result_file('MarginResult.csv');
    my $logtxt = parse_result_file('log.txt');
    my $logyml = parse_result_file('log.yml');

    my $state = $exit_code == 0 ? 'PASS' : 'FAIL';
    my $summary = [];
    push @$summary, '=== Hardware Summary ===';
    push @$summary, 'Device ID : ' . detect_device_id();
    my ($vendor, $size) = detect_mem_info();
    push @$summary, 'VRAM Size : ' . $size . ' MB';
    push @$summary, 'Vendor    : ' . $vendor;
    push @$summary, 'PCIe Width: ' . detect_pci_width();
    push @$summary, '';
    push @$summary, '=== Result Files ===';
    push @$summary, 'errorid.tmp : ' . ($errorid ? 'found' : 'missing');
    push @$summary, 'MarginResult.csv : ' . ($margin ? 'found' : 'missing');
    push @$summary, 'log.txt : ' . ($logtxt ? 'found' : 'missing');
    push @$summary, 'log.yml : ' . ($logyml ? 'found' : 'missing');
    push @$summary, '';
    push @$summary, '=== Channel/Memory Notes ===';
    push @$summary, join("\n", extract_channel_summary($margin));
    push @$summary, '';
    push @$summary, 'Overall verdict : ' . $state;

    print render_banner($state, 'NAVI23 DIAGNOSTIC REPORT');
    print "\n";
    print join("\n", @$summary), "\n";

    my $stamp = strftime('%Y%m%d_%H%M%S', localtime);
    make_path($log_dir) unless -d $log_dir;
    my $out_file = "$log_dir/[$state]_${serial}_${stamp}.log";
    open my $out_fh, '>', $out_file or die "No se pudo escribir $out_file\n";
    print {$out_fh} join("\n", @$summary), "\n";
    close $out_fh;
    print "\n[LOG] Report saved to $out_file\n";
}

if ($mode eq 'validate') {
    exit validate_hardware();
} elsif ($mode eq 'parse') {
    parse_results($exit_code);
    exit 0;
} else {
    die "Debe especificar --validate o --parse <exit_code>\n";
}
