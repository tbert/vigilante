#! /usr/bin/perl
#
# Copyright (c) 2013 Bret Stephen Lambert <bret@theapt.org>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

use strict;
use warnings;

#
# File::Stream is available at
#     https://metacpan.org/module/File::Stream
# with a hidden dependency which is available at
#     https://metacpan.org/module/YAPE::Regex
#
use File::Stream;
use Getopt::Std;

use lib "lib/";		# XXX -- for testing only!

use Vigilante;

use feature "switch";

sub errorclass($) {
	my $errstr = shift;

	given ($errstr) {
		when (/Result .* converted .* incompatible/)	{ return "RTRN"; }
		when (/[Uu]se .* after .* free/)		{ return "UAF";  }
		when (/[Nn]ull pointer/)			{ return "NULL"; }
		when (/never read/)				{ return "DEDS"; }
		when (/never reached/)				{ return "DEDC"; }
		when (/garbage/)				{ return "INIT"; }
		when (/undefined/)				{ return "INIT"; }
		when (/allocation size/)			{ return "UNTR"; }
		default			{ die("Undefined defect class for $errstr"); }
	}
}

my $report;
my $errstream;
my %opts;

my $project = undef;

getopt("p:", \%opts);

$project = $opts{"p"}	if (defined($opts{"p"}));

die("Project name not defined")		if (!defined($project));

$errstream = File::Stream->new(\*STDIN, separator => qr/[0-9]+ warnings? generated\./);

$report = Vigilante::Report->new();
$report->set_tool("clang static analyzer");
$report->set_project($project);

while (<$errstream>) {

	my $input = $_;

	$input =~ s/In file included from.*[0-9]+:\n//g;
	$input =~ s/[0-9]+ warnings? generated\.//g;

	while ($input =~ /((.*):([0-9]+):[0-9]+: warning: (.*)\n(.*)\n)/) {

		my $defect = Vigilante::Defect->new();

		my $raw = $1;
		my $file = $2;
		my $lineno = $3;
		my $errstr = $4;
		my $defect_line = $5;

		$defect->set_raw($raw);
		$defect->set_file($file);
		$defect->set_lineno($lineno);
		$defect->set_errstr($errstr);
		$defect->set_defect_line($defect_line);
		$defect->set_class(errorclass($raw));

		$input = substr($input, length($raw) + 1);
		$input =~ s/^\s//;

		$report->append($defect);
	}
}

$report->report(\*STDOUT);

exit 0;
