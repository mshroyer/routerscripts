#!/usr/bin/env perl

use warnings;
use strict;

use Pod::Usage;
use Getopt::Long;
use Net::IP qw(:PROC);

my ($help, $subnet);

GetOptions(
    'subnet|s=s'  => \$subnet,
    'help|?' => \$help,
) or die "Incorrect usage!\n";

pod2usage(1) if $help;

if (@ARGV != 1) {
    die "Usage: $0 --subnet <subnet_prefix/prefix_length> <input_zone_file>\n";
}

my $input_file = $ARGV[0];
my $subnet_obj = new Net::IP($subnet) or die(Net::IP::Error());
my $ip_version = $subnet_obj->version();
my $origin = "";

open(my $input_fh, '<', $input_file) or die "Cannot open input file: $!";

while (my $line = <$input_fh>) {
    chomp($line);

    if ($line =~ /^\$ORIGIN\s+(\S+)/) {
        $origin = $1;
    } elsif ($line =~ /^\$TTL\s+\S+/) {
        print "$line\n\n";
    } elsif ($ip_version == 4 && $line =~ /^\s*(\S+)\s+A\s+(\S+)/) {
        my ($hostname, $ipv4) = ($1, $2);
        my $ip_obj = new Net::IP($ipv4) or die(Net::IP::Error());
        if ($subnet_obj->overlaps($ip_obj) != $IP_NO_OVERLAP) {
            my $reverse_ipv4 = join('.', reverse(split(/\./, $ipv4))) . ".in-addr.arpa";
            print "$reverse_ipv4\tPTR\t$hostname.$origin\n";
        }
    } elsif ($ip_version == 6 && $line =~ /^\s*(\S+)\s+(\d+)\s+IN\s+AAAA\s+(\S+)/) {
        print "IPv6\n";
        my ($hostname, $ttl, $ipv6) = ($1, $2, $3);
        my $ip_obj = new Net::IP($ipv6) or die(Net::IP::Error());
        if ($subnet_obj->overlaps($ip_obj) != $IP_NO_OVERLAP) {
            my $reverse_ipv6 = $ip_obj->reverse_ip();
            print "$reverse_ipv6\t$ttl\tPTR\t$hostname.$origin\n";
        }
    }
}

close($input_fh);

__END__

=head1 NAME

rdns.pl - Generate reverse DNS zone files

=head1 SYNOPSIS

rdns.pl --input-path foo.zone

=cut