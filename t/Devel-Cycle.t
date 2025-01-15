# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Devel-Cycle.t'

#########################

use Test::More tests => 12;
use Scalar::Util qw(weaken isweak);
BEGIN { use_ok('Devel::Cycle') };

#########################

my $test = {fred   => [qw(a b c d e)],
	ethel  => [qw(1 2 3 4 5)],
	george => {martha => 23,
		agnes  => 19},
	};
	$test->{george}{phyllis} = $test;
	$test->{fred}[3]      = $test->{george};
	$test->{george}{mary} = $test->{fred};

	my ($test2, $test3);
	$test2 = \$test3;
	$test3 = \$test2;

	my $counter = 0;
	find_cycle($test, sub { $counter++ });
	is($counter, 4, 'found four cycles in $test');

	$counter = 0;
	find_cycle($test2, sub { $counter++ });
	is($counter, 1, 'found one cycle in $test2');

# now fix them with weaken and make sure that gets noticed
$counter = 0;
weaken($test->{george}->{phyllis});
find_cycle($test, sub { $counter++ });
is($counter, 2, 'found two cycles in $test after weaken()');

# uncomment this to test the printing
# diag "Not Weak";
# find_cycle($test);
# diag "Weak";
# find_weakened_cycle($test);

$counter = 0;
find_weakened_cycle($test, sub { $counter++ });
is($counter, 4, 'found four cycles (including weakened ones) in $test after weaken()');

$counter = 0;
weaken($test->{fred}[3]);
find_cycle($test, sub { $counter++ });
is($counter, 0, 'found no cycles in $test after second weaken()');

$counter = 0;
find_weakened_cycle($test, sub { $counter++ });
is($counter, 4, 'found four cycles (including weakened ones) in $test after second weaken()');

# GLOB reference test
{
	*FOOBAR = undef;
	my $ref = \*FOOBAR;
	*FOOBAR = $ref;
	my $test_glob = { glob => \*FOOBAR };

	$counter = 0;
	find_cycle($test_glob, sub { $counter++ });
	is($counter, 0, 'no cycle detected for GLOB reference');
}

# IO reference test
{
	open my $fh, '<', \$0 or die $!;
	my $test_io = { io => $fh };

	$counter = 0;
	find_cycle($test_io, sub { $counter++ });
	is($counter, 0, 'found no cycle in IO reference');
	close $fh;
}

# Regexp reference test
{
	my $test_regexp = { regex => qr/foo/ };
	$counter = 0;
	find_cycle($test_regexp, sub { $counter++ });
	is($counter, 0, 'found no cycles in Regexp reference');
}

# False alarm with overloaded objects
{
	package foo;
	use overload q("") => sub { return 1 };

	package bar;
	use overload q("") => sub { return 1 };

	package main;
	my $a = bless {}, 'foo';
	my $b = bless {}, 'bar';
	$a->{'b'} = $b;

	$counter = 0;
	find_cycle($a, sub { $counter++ });
	is($counter, 0, 'found no cycles in overloaded objects creating false alarms');
}

# Cyclical closure test
SKIP: {
	skip 'These tests require PadWalker 1.0+', 1
	unless Devel::Cycle::HAVE_PADWALKER;

	$counter = 0;

	my %cyclical = (a => [],
		b => {},
		);
	$cyclical{a}[0]   = $cyclical{a};
	$cyclical{b}{key} = $cyclical{a};

	my @cyclical = [];
	$cyclical[0] = \@cyclical;

	my $sub = sub { return \@cyclical, \%cyclical; };

	find_cycle($sub, sub { $counter++ });
	is($counter, 3, 'found three cycles in $cyclical closure');
}
