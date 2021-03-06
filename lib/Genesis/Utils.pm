package Genesis::Utils;

use base 'Exporter';
our @EXPORT = qw/
	envset envdefault

	csprintf
	explain debug trace error

	workdir
/;

use File::Temp qw/tempdir/;

sub envset {
	my ($var) = @_;
	return (defined $ENV{$var} and $ENV{$var} =~ m/^(1|y|yes|true)$/i);
}

sub envdefault {
	my ($var, $default) = @_;
	return defined $ENV{$var} ? $ENV{$var} : $default;
}

sub ago {
	my ($ts) = @_;
	my $ago = time - $ts;
	if ($ago >  90 * 86400) { return sprintf("%i months ago", $ago / 30 / 86400); }
	if ($ago >= 21 * 86400) { return sprintf("%i weeks ago", $ago / 7  / 86400); }
	if ($ago >= 2  * 86400) { return sprintf("%i days ago", $ago / 86400); }
	if ($ago >= 90 * 60)    { return sprintf("%i hours ago", $ago / 3600); }
	if ($ago >  60)         { return sprintf("%i minutes ago", $ago / 60); }
	return "just now";
}

sub colorize {
	my ($c, $msg) = @_;
	return $msg if envset('NOCOLOR');
	$c = substr $c, 1, 1;
	my %color = (
		'k'		=> "\e[30m",     #black
		'K'		=> "\e[1;30m",   #black (BOLD)
		'r'		=> "\e[31m",     #red
		'R'		=> "\e[1;31m",   #red (BOLD)
		'g'		=> "\e[32m",     #green
		'G'		=> "\e[1;32m",   #green (BOLD)
		'y'		=> "\e[33m",     #yellow
		'Y'		=> "\e[1;33m",   #yellow (BOLD)
		'b'		=> "\e[34m",     #blue
		'B'		=> "\e[1;34m",   #blue (BOLD)
		'm'		=> "\e[35m",     #magenta
		'M'		=> "\e[1;35m",   #magenta (BOLD)
		'p'		=> "\e[35m",     #purple (alias for magenta)
		'P'		=> "\e[1;35m",   #purple (BOLD)
		'c'		=> "\e[36m",     #cyan
		'C'		=> "\e[1;36m",   #cyan (BOLD)
		'w'		=> "\e[37m",     #white
		'W'		=> "\e[1;37m",   #white (BOLD)
	);

	if ($c eq "*") {
		my @rainbow = ('R','G','Y','B','M','C');
		my $i = 0;
		my $msgc = "";
		foreach my $char (split //, $msg) {
			$msgc = $msgc . "$color{$rainbow[$i%6]}$char";
			if ($char =~ m/\S/) {
				$i++;
			}
		}
		return "$msgc\e[0m";
	} else {
		return "$color{$c}$msg\e[0m";
	}
}

sub csprintf {
	my ($fmt, @args) = @_;
	return '' unless $fmt;
	my $s = sprintf($fmt, @args);
	$s =~ s/(#[KRGYBMPCW*]\{)(.*?)(\})/colorize($1, $2)/egi;
	return $s;
}
sub explain(@) {
	return if envset "QUIET";
	my $colorize = $ENV{NOCOLOR};
	$ENV{NOCOLOR} = "true" if (! -t STDOUT);
	print csprintf(@_);
	$ENV{NOCOLOR} = $colorize;
	print "\n";
}

sub debug(@) {
	return unless envset "GENESIS_DEBUG";
	print STDERR "DEBUG> ";
	my $colorize = $ENV{NOCOLOR};
	$ENV{NOCOLOR} = "true" if (! -t STDERR);
	print STDERR csprintf(@_);
	$ENV{NOCOLOR} = $colorize;
	print STDERR "\n";
}

sub trace(@) {
	return unless envset "TRACE";
	print STDERR "TRACE> ";
	print STDERR csprintf(@_);
	print STDERR "\n";
}

sub error(@) {
	my @err = @_;
	unshift @err, "%s" if $#err == 0;
	print STDERR csprintf(@err) . "\n";
}

my %WORKDIR;
sub workdir {
	return $WORKDIR{$_[0]} if ($_[0] && defined $WORKDIR{$_[0]});
	my $dir = tempdir(CLEANUP => 1);
	$WORKDIR{$_[0]} = $dir if $_[0];
	return $dir;
}

1;
