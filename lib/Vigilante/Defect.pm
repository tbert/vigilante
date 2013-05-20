package Vigilante::Defect;

use strict;
use warnings;

sub new {
	my($this, %cnf) = @_;
	my $class = ref($this) || $this;

	my $self = bless {
			errstr      => "",
			defect_line => "",
			file        => "",
			lineno      => "",
			type        => "",
			raw         => ""
		}, $class;

	$self->{"errstr"} = $cnf{"errstr"}		if (defined($cnf{"errstr"}));
	$self->{"defect_line"} = $cnf{"defect_line"}	if (defined($cnf{"defect_line"}));
	$self->{"file"}	 = $cnf{"file"}			if (defined($cnf{"file"}));
	$self->{"lineno"} = $cnf{"lineno"}		if (defined($cnf{"lineno"}));
	$self->{"type"} = $cnf{"type"}			if (defined($cnf{"type"}));
	$self->{"raw"} = $cnf{"raw"}			if (defined($cnf{"raw"}));

	return $self;
}

sub set_errstr($) {
	my ($self, $errstr) = @_;

	$self->{"errstr"} = $errstr;
}

sub set_defect_line($) {
	my ($self, $defect_line) = @_;

	$self->{"defect_line"} = $defect_line;
}

sub set_file($) {
	my ($self, $file) = @_;

	$self->{"file"} = $file;
}

sub set_lineno($) {
	my ($self, $lineno) = @_;

	$self->{"lineno"} = $lineno;
}

sub set_type($) {
	my ($self, $type) = @_;

	$self->{"type"} = $type;
}

sub set_raw($) {
	my ($self, $raw) = @_;

	$self->{"raw"} = $raw;
}

1;
