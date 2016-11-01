#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

if (not $ENV{RELEASE_TESTING}) { plan skip_all => 'Release test should only be run on release.'; }

plan tests => 142;

use Encode qw/ decode encode /;
use File::Share qw/ dist_file /;
use Carp::Always;
use JSON::MaybeXS qw/ decode_json /;
use Data::Munge qw/ slurp /;

use Time::C;
use Time::P;
use Time::F;

binmode STDERR, ":encoding(UTF-8)";

sub in {
    my ($n, @h) = @_;
    foreach my $s (@h) { return 1 if $n eq $s; }
    return 0;
}

my $fn = dist_file 'Time-C', 'locale.db';
open my $fh, '<', $fn or die "Could not open $fn: $!";
my $loc_db = decode_json slurp $fh;

sub loc_db_entries {
    my $l = shift;
    my %entries = map { $_, $loc_db->{$_}{$l} } grep { ref $loc_db->{$_} eq 'HASH' and exists $loc_db->{$_}{$l} } keys %{ $loc_db };
    my @entries;
    foreach my $k (sort keys %entries) {
        my $entry = $entries{$k};
        if (ref $entry eq 'ARRAY') { $entry = join ", ", @{ $entry }; }
        push(@entries, sprintf "%s: %s", $k, $entry);
    }
    return join "\n", @entries;
}

foreach my $l (sort keys %{ $loc_db->{r_fmt} }) {
SKIP: {
    skip "$l => Charset issues.", 1 if in ($l => qw/ nan_TW@latin tt_RU@iqtelif sd_IN@devanagari ks_IN@devanagari /);
    skip "$l => Not a proper locale.", 1 if in ($l => qw/ i18n /);

    my $t = Time::C->now_utc()->second_of_day(0);

    my $str = eval { strftime($t, '%r', locale => $l); };
    skip "Could not strftime.", 1 if not defined $str;

    note encode 'UTF-8', "$l => $str";
    my $p = eval { strptime($str, "%r", locale => $l); };

    if (defined $p) {
        cmp_ok ($p->epoch - $t->epoch, '>=', '-60', "$l => Correct time calculated!") or
          diag sprintf("Error: %s\nStr: %s\n%s\n\n", "$p is not close enough to $t", $str, loc_db_entries($l));
    } else {
        my $err = $@;
        if ($err =~ /^Unsupported format specifier: (%\S+)/) {
            skip "$l => Unsupported format specifier: $1", 1;
        } else {
            fail "$l => Correct time calculated!";
            diag sprintf("Error: %s\nStr: %s\n%s\n\n",
              encode('UTF-8', $err),
              $str,
              loc_db_entries($l));
        }
    }
}
}

#done_testing;
