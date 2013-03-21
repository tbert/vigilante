package Vigilante::UnifiedDiff;

use strict;
use warnings;

use Exporter;

our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

sub new () {
	my $this = shift;
	my $class = ref($this) || $this;

	my $self = bless {}, $class;
	return $self;
}

sub parse_fh($) {
	my ($self, $fh) = @_;

	while (my $line = <$fh>) {
		parse_line($self, $line);
	}
}

sub parse($) {
	my ($self, $str) = @_;
	my @lines = split(/^/, $str);

	foreach my $line (@lines) {
		parse_line($self, $line);
	}
}

sub parse_line($$) {
	my ($patch, $line) = @_;

	if ($line =~ /^[Ii]ndex:\s*([\S ]+)/) {

		#my $index= $1;

	} elsif ($line =~ /^@@\s*-(\d+),?(\d*)\s*\+(\d+),?(\d*)\s*(?:@@\s*(.*))?/) {
		my @oldtext = ();
		my @newtext = ();
		my $old = { "start" => $1, "count" => $2, "text" => \@oldtext };
		my $new = { "start" => $3, "count" => $4, "text" => \@newtext };

		push(@{@{$patch->{$patch->{"curfile"}}->{"sections"}}[0]}, $old);
		push(@{@{$patch->{$patch->{"curfile"}}->{"sections"}}[1]}, $new);

	} elsif ($line =~ /^---\s*([^\s\\]+)\s+.*/) {

		$patch->{"curoldfilename"} = $1;

	} elsif ($line =~ /^\+\+\+\s*([^\s\\]+)\s+.*/) {
		my @old = ();
		my @new = ();
		my @sections = (\@old, \@new);

		$patch->{"curfile"} = $1;
		$patch->{$patch->{"curfile"}} = { };
		$patch->{$patch->{"curfile"}}->{"oldname"} = $patch->{"curoldfilename"};
		$patch->{$patch->{"curfile"}}->{"sections"} = \@sections;

	} elsif (substr($line, 0, 1) eq '+') {
		my $new = @{@{$patch->{$patch->{"curfile"}}->{"sections"}}[1]}[-1];

		push(@{$new->{"text"}}, substr($line, 1));

	} elsif (substr($line, 0, 1) eq '-') {
		my $old = @{@{$patch->{$patch->{"curfile"}}->{"sections"}}[0]}[-1];

		push(@{$old->{"text"}}, substr($line, 1));

	} elsif (substr($line, 0, 1) eq ' ') {
		my $old = @{@{$patch->{$patch->{"curfile"}}->{"sections"}}[0]}[-1];
		my $new = @{@{$patch->{$patch->{"curfile"}}->{"sections"}}[1]}[-1];

		push(@{$old->{"text"}}, substr($line, 1));
		push(@{$new->{"text"}}, substr($line, 1));

	}
}

sub line($$) {
	my ($self, $file, $lineno) = @_;	# XXX -- validate arguments

	return undef	if (!defined($self->{$file}));

	foreach my $section (@{@{$self->{$file}->{"sections"}}[1]}) {
		next	if ($section->{"start"} > $lineno);
		next	if ($section->{"start"} + $section->{"count"} < $lineno);

		my $line = @{$section->{"text"}}[$lineno - $section->{"start"}];

		return $line;
	}

	return undef;
}

sub prev_line($$) {
	my ($self, $file, $lineno) = @_;
	my $i = 0;

	return undef	if (!defined($self->{$file}));

	# loop over the diff sections, operating on the corresponding previous text
	foreach my $section (@{@{$self->{$file}->{"sections"}}[1]}) {
		$i++;

		next	if ($section->{"start"} > $lineno);
		next	if ($section->{"start"} + $section->{"count"} < $lineno);

		# NB - this is naive, but works for single-line changes

		my $oldsection = @{@{$self->{$file}->{"sections"}}[0]}[$i - 1];
		my $offset = $oldsection->{"count"} - $section->{"count"};
		my $line = @{$oldsection->{"text"}}[$lineno - $section->{"start"} + $offset];

		return $line;
	}

	return undef;
}

1;
