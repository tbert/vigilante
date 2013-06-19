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

use Storable qw(fd_retrieve);
use Regexp::Assemble;
use Config::Tiny;
use DBD::SQLite;
use Data::UUID;
use DBI;

use lib "lib/";		# XXX -- for testing only!

use Vigilante;

use Data::Dumper;	# XXX -- for testing only!

use feature "switch";

sub parseconfig($$);
sub parsereport();
sub getprojectID($$);
sub duplicateID($$$);
sub createScan($$$$);
sub uuid();
sub skipsignature($);
sub loadsignatures($);

my $createProjects = 1;		# XXX -- 'true' default for testing only!

my $dbname;
my $dbtype;
my $dbuser;
my $dbpass;

my $confpath = "./vigilante.conf";	# XXX
my %config;
my $report;
my $dbh;
my $sth;
my $dupsth;
my $sql;
my $patch = undef;
my $ra;
my $projectID;
my $scanID;

$report = parsereport();
parseconfig($confpath, $report);

if (defined($dbtype)) {
	$dbh = DBI->connect("dbi:$dbtype:dbname=$dbname", $dbuser, $dbpass,
			    { RaiseError => 0, AutoCommit => 0});

	$projectID = getprojectID($dbh, $report->{"project"});
	$scanID = createScan($dbh, $projectID, $report->{"tool"}, "");

	$sql  = "INSERT INTO Defects (scanID, file, lineno, line, raw, duplicateOf, classID) ";
	$sql .= "SELECT ?,?,?,?,?,?,(SELECT ID from DefectClasses where textID = ?)";

	$sth = $dbh->prepare($sql);

	$sql  = "SELECT Defects.ID as defectID, Defects.duplicateOf as dupID FROM Defects ";
	$sql .= "JOIN Scans ON Defects.scanID = Scans.ID ";
	$sql .= "JOIN Projects ON Scans.projectID = Projects.ID ";
	$sql .= "WHERE Defects.line = ? ";
	$sql .= "AND Projects.ID = ?";

	$dupsth = $dbh->prepare($sql);
}

foreach my $defect (@{$report->{"defects"}}) {
	my $class  = "NULL";
	my $file   = "NULL";
	my $lineno = "NULL";
	my $line   = "NULL";
	my $raw    = "NULL";
	my $dupID  = "NULL";

	$class  = $defect->{"class"}	if defined($defect->{"class"});
	$file   = $defect->{"file"}	if defined($defect->{"file"});
	$lineno = $defect->{"lineno"}	if defined($defect->{"lineno"});
	$line   = $defect->{"line"}	if defined($defect->{"line"});
	$raw    = $defect->{"raw"}	if defined($defect->{"raw"});

	next	if (skipsignature($defect->{"raw"}));

	if (defined($dbtype)) {
		if (defined($patch) and $file ne "NULL" and $lineno ne "NULL") {
			$dupID = duplicateID($dupsth, $file, $lineno);
		}

		$sth->execute($scanID, $file, $lineno, $line, $raw, $dupID, $class);
	}
}

if (defined($dbtype)) {
	$dbh->commit();
	$dbh->disconnect();
}

exit 0;

# Parse project configuration from provided path
sub parseconfig($$) {
	my $path = shift;
	my $r = shift;
	my $project = $r->{"project"};
	my $conf;
	my %confhash;
	my ($u, $p, $d, $l, $t) = (undef, undef, undef, undef, undef);

	$conf = Config::Tiny->read($path) or die("Unable to parse $path: $!");

	die("Undefined project")		if (! defined($project));
	die("Unknown project '$project'")	if (! defined($conf->{$project}));

	# grab default options from config file
	$u = $conf->{_}->{"user"}	if (defined($conf->{_}->{"user"}));
	$p = $conf->{_}->{"pass"}	if (defined($conf->{_}->{"pass"}));
	$t = $conf->{_}->{"database"}	if (defined($conf->{_}->{"database"}));
	$l = $conf->{_}->{"location"}	if (defined($conf->{_}->{"location"}));

	# grab project-specific configuration options
	$u = $conf->{$project}->{"user"}	if (defined($conf->{$project}->{"user"}));
	$p = $conf->{$project}->{"pass"}	if (defined($conf->{$project}->{"pass"}));
	$t = $conf->{$project}->{"database"}	if (defined($conf->{$project}->{"database"}));
	$l = $conf->{$project}->{"location"}	if (defined($conf->{$project}->{"location"}));

	$dbuser = $u	if (defined($u));
	$dbpass = $p	if (defined($p));
	$dbtype = $t	if (defined($t));
	$dbname = $l	if (defined($l));

	die("Database location not provided")	if(defined($dbtype) && ! defined($dbname));
}

sub parsereport() {
	my $r = fd_retrieve(\*STDIN);

	die("Report does not include project name")	  if (! defined($r->{"project"}));
	die("Report does not include defects")		  if (@{$r->{"defects"}} <= 0);
	die("Report does not include scanning tool name") if (! defined($r->{"tool"}));

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

	return $d->last_insert_id("", "", "", "");	# XXX
}

sub uuid() {
	my $uuid = Data::UUID->new();
	return $uuid->create_str();
}

sub skipsignature($) {
	my $raw = shift;

	if (defined($ra)) {
		return $ra->match($raw);
	} else {
		return 0;
	}
}

sub loadsignatures($) {
	my $sigfile = shift;
	my $sigfh;
	my $regex;

	$regex = Regexp::Assemble->new();

	open($sigfh, "<", $sigfile) or die("could not open signature file: $sigfile");

	while (<$sigfh>) {
		chomp;
		next	if (/^$/);
		next	if (/^#/);

		$regex->add($_);
	}

	close($sigfh);

	return $regex;
}
