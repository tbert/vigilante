package Vigilante::Defect;

use strict;
use warnings;

sub new {
	my($this, %cnf) = @_;
	my $class = ref($this) || $this;

	my $self = bless {
			errstr => "",
			line   => "",
			file   => "",
			lineno => "",
			class  => "",
			raw    => ""
		}, $class;

	$self->{"errstr"} = $cnf{"errstr"}	if (defined($cnf{"errstr"}));
	$self->{"line"}   = $cnf{"line"}	if (defined($cnf{"line"}));
	$self->{"file"}	  = $cnf{"file"}	if (defined($cnf{"file"}));
	$self->{"lineno"} = $cnf{"lineno"}	if (defined($cnf{"lineno"}));
	$self->{"class"}  = $cnf{"class"}	if (defined($cnf{"class"}));
	$self->{"raw"}    = $cnf{"raw"}		if (defined($cnf{"raw"}));

	return $self;
}

sub set_errstr($) {
	my ($self, $errstr) = @_;

	$self->{"errstr"} = $errstr;
}

sub set_line($) {
	my ($self, $line) = @_;

	$self->{"line"} = $line;
}

sub set_file($) {
	my ($self, $file) = @_;

	$self->{"file"} = $file;
}

sub set_lineno($) {
	my ($self, $lineno) = @_;

	$self->{"lineno"} = $lineno;
}

sub set_class($) {
	my ($self, $class) = @_;

	$self->{"class"} = $class;
}

sub set_raw($) {
	my ($self, $raw) = @_;

	$self->{"raw"} = $raw;
}

1;
