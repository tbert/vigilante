package Vigilante::Report;

use strict;
use warnings;

use Scalar::Util qw(openhandle);
use Storable qw(store_fd);
use Exporter;
use Carp;

our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

sub new() {
	my ($this, %cnf) = @_;
	my $class = ref($this) || $this;

	my $self = bless {
			tool    => "",
			project => "",
			date    => "",
			diff    => "",
			extid   => "",
			defects => undef
		}, $class;

	$self->{"tool"}    = $cnf{"tool"}	if (defined($cnf{"tool"}));
	$self->{"date"}    = $cnf{"date"}	if (defined($cnf{"date"}));
	$self->{"diff"}    = $cnf{"diff"}	if (defined($cnf{"diff"}));
	$self->{"defects"} = $cnf{"defects"}	if (defined($cnf{"defects"}));

	return $self;
}

sub set_tool($) {
	my ($self, $tool) = @_;

	$self->{"tool"} = $tool;	# XXX -- validate
}

sub set_project($) {
	my ($self, $project) = @_;

	$self->{"project"} = $project;	# XXX -- validate
}

sub set_date($) {
	my ($self, $date) = @_;
	my $dt;

	if (! defined($date)) {
		croak("");
		return;
	}

	$dt = DateTime::Format::ISO8601->parse_datetime($date);

	if (! defined($dt)) {
		croak("");
		return;
	}

	$self->{"date"} = $date;
}

sub set_diff($) {
	my ($self, $diff) = @_;

	$self->{"diff"} = $diff;
}

sub set_extid($) {
	my ($self, $extid) = @_;

	$self->{"extid"} = $extid;
}

# append a Vigilante::Defect to the report
sub append($) {
	my ($self, $defect) = @_;

	unless ($defect->isa("Vigilante::Defect")) {
		croak("Vigilante: passed argument is not of type Vigilante::Defect");
		return;
	}

	push(@{$self->{"defects"}}, $defect);
}

# send Vigilante's report to the provided filehandle
sub report($) {
	my ($self, $fh) = @_;
	my $canonical;

	if (! defined(openhandle($fh))) {
		carp("Vigilante: passed argument is not an open filehandle");
		return;
	}

	#
	# lexical ordering of stored hash keys,
	# without clobbering other users of the module
	#
	$canonical = $Storable::canonical;
	$Storable::canonical = 1;

	store_fd($self, $fh);

	$Storable::canonical = $canonical;
}

sub dump() {
	my $self = shift;	# XXX -- force the passing of no arguments
	print Data::Dumper::Dumper($self);
}

1;
