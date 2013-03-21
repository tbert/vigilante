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

use Config::General qw(ParseConfig);
use Storable qw(fd_retrieve);
use DBD::SQLite;
use Data::UUID;
use DBI;

use lib "lib/";

use Vigilante;

use Data::Dumper;	# XXX -- for testing only!

use feature "switch";

my $createProjects = 1;		# XXX -- 'true' default for testing only!

my $dbname = "vigilante.db";
my $dbtype = "SQLite";
my $dbuser = "";
my $dbpass = "";

my $confpath = "./vigilante.conf";	# XXX
my %config;
my $report;
my $dbh;
my $sth;
my $sql;
my $patch = undef;

sub parseconfig($$);
sub parsereport();
sub getprojectID($$);
sub duplicateID($$$);
sub createScan($$$$);
sub uuid();
sub skipsignature($);
sub loadsignatures($);

$report = parsereport();
parseconfig($confpath, $report);

$dbh = DBI->connect("dbi:$dbtype:dbname=$dbname", $dbuser, $dbpass,
                    { RaiseError => 0, AutoCommit => 0});

my $dupsth;
my $projectID = getprojectID($dbh, $report->{"project"});
my $scanID = createScan($dbh, $projectID, $report->{"tool"}, "");

$sql  = "INSERT INTO Defects (scanID, file, lineno, line, raw, duplicateOf, classID) ";
$sql .= "SELECT ?,?,?,?,?,?,(SELECT ID from DefectClasses where textID = ?)";

$sth = $dbh->prepare($sql);

$sql  = "SELECT Defects.ID as defectID, Defects.duplicateOf as dupID FROM Defects ";
$sql .= "JOIN Scans ON Defects.scanID = Scans.ID ";
$sql .= "JOIN Projects ON Scans.projectID = Projects.ID ";
$sql .= "WHERE Defects.line = ? ";
$sql .= "AND Projects.ID = ?";

$dupsth = $dbh->prepare($sql);

foreach my $defect (@{$report->{"defects"}}) {
	my $class  = "NULL";
	my $file   = "NULL";
	my $lineno = "NULL";
	my $line   = "NULL";
	my $raw    = "NULL";
	my $dupID  = "NULL";

	$class  = $defect->{"type"}	if defined($defect->{"type"});
	$file   = $defect->{"file"}	if defined($defect->{"file"});
	$lineno = $defect->{"lineno"}	if defined($defect->{"lineno"});
	$line   = $defect->{"line"}	if defined($defect->{"line"});
	$raw    = $defect->{"raw"}	if defined($defect->{"raw"});

	next	if (skipsignature($defect->{"raw"}));

	if (defined($patch) and $file ne "NULL" and $lineno ne "NULL") {
		$dupID = duplicateID($dupsth, $file, $lineno);
	}

	$sth->execute($scanID, $file, $lineno, $line, $raw, $dupID, $class);
}

$dbh->commit();
$dbh->disconnect();

exit 0;

# Parse project configuration from provided path
sub parseconfig($$) {
	my $path = shift;
	my $r = shift;
	my $project = $r->{"project"};
	my $conf;
	my %confhash;
	my ($u, $p, $d, $l, $t) = (undef, undef, undef, undef, undef);

	# XXX -- think about using -Tie to limit the keys?
	$conf = new Config::General(
			-ConfigFile       => $path,
			-InterPolateVars  => 1,
			-StrictVars       => 1,
			-UseApacheInclude => 1,
			-IncludeRelative  => 1,
			-IncludeGlob      => 1,
		) or die("Could not load configuration file $path");

	%confhash = $conf->getall();

	# grab default options from config file
	$u = $confhash{"user"}		if (defined($confhash{"user"}));
	$p = $confhash{"pass"}		if (defined($confhash{"pass"}));
	$t = $confhash{"database"}	if (defined($confhash{"database"}));
	$l = $confhash{"location"}	if (defined($confhash{"location"}));

	my $pconf = $confhash{"project"}->{$project};

	# grab project-specific configuration options
	if (defined($pconf)) {
		if (defined($pconf->{"database"})) {

			# unpack the hash, or assign the scalar
			if (ref($pconf->{"database"}) eq "HASH") {
				my @k = keys(%{$pconf->{"database"}});

				die("Multiple database definitions for $project") if (@k > 1);

				given ($k[0]) {
					when ("MySQL")		{ $t = "mysql" }
					when ("SQLite")		{ $t = "SQLite" }
					when ("PostgreSQL")	{ $t = "Pg" }
					default {
						die("Unknown database type $k[0]");
					}
				}

				$u = $pconf->{"database"}->{$k[0]}->{"user"}
				    if (defined($pconf->{"database"}->{$k[0]}->{"user"}));
				$p = $pconf->{"database"}->{$k[0]}->{"pass"}
				    if (defined($pconf->{"database"}->{$k[0]}->{"pass"}));
				$l = $pconf->{"database"}->{$k[0]}->{"line"}
				    if (defined($pconf->{"database"}->{$k[0]}->{"location"}));
			} else {
				$t = $pconf->{"database"};
			}
		}
	}

	$dbuser = $u	if (defined($u));
	$dbpass = $p	if (defined($p));
	$dbtype = $t	if (defined($t));
	$dbname = $l	if (defined($l));
}

sub parsereport() {
	my $r = fd_retrieve(\*STDIN);

	die("Report does not include project name")	  if (! defined($r->{"project"}));
	die("Report does not include defects")		  if (@{$r->{"defects"}} <= 0);
	die("Report does not include name scanning tool") if (! defined($r->{"tool"}));

	$patch = $r->{"diff"}	if ($r->{"diff"});

	return $r;
}

sub getprojectID($$) {
	my $h = shift;
	my $p = shift;
	my $row;

	$row = $h->selectrow_hashref("SELECT * from Projects WHERE name = '$p'");

	if ($row->{"ID"}) {
		return $row->{"ID"}
	} elsif ($createProjects == 1) {
		$h->do("INSERT INTO Projects (name) VALUES ('$p')");
		return $h->last_insert_id("","","","");
	} else {
		$h->disconnect();
		die("Unknown project '$p'");
	}
}

sub duplicateID($$$) {
	my $sth = shift;
	my $line = shift;
	my $pID = shift;

	$sth->execute($line, $pID);

	my $row = sth->fetchall_hashref();

	return "$row->{'dupID'}"	if ($row->{'dupID'});
	return "$row->{'defectID'}"	if ($row->{'defectID'});
	return "NULL";
}

sub createScan($$$$) {
	my ($d, $pID, $tool, $extID) = @_;
	my $uuid = uuid();

	$sql  = "INSERT INTO Scans (projectID, tool, uuid, externalID) ";
	$sql .= "VALUES ('$pID', '$tool', '$uuid', '$extID');";

	$d->do($sql);

	return $d->last_insert_id("", "", "", "");
}

sub uuid() {
	my $uuid = new Data::UUID;
	return $uuid->create_str();
}

sub skipsignature($) {
	my $raw = shift;

	return 0;
}

sub loadsignatures($) {
	my $sigfile = shift;
	my $sigfh;
	my @sigs;

	open($sigfh, $sigfile) or die("could not open signature file: $sigfile");

	while (<$sigfh>) {
		chomp;
		next	if (/^$/);
		next	if (/^#/);

		push(@sigs, $_);
	}

	close($sigfh);

	return \@sigs;
}
