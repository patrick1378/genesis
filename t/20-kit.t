#!perl
use strict;
use warnings;

use lib 'lib';
use lib 't';
use helper;
use Test::Deep;

use_ok 'Genesis::Kit';
use_ok 'Genesis::Kit::Compiled';
use_ok 'Genesis::Kit::Dev';
use Genesis::Kit::Compiler;

sub kit {
	my ($name, $version) = @_;
	$version ||= 'latest';
	my $tmp = workdir;
	my $file = Genesis::Kit::Compiler->new('t/src/simple')->compile($name, $version, $tmp);

	return Genesis::Kit::Compiled->new(
		name    => $name,
		version => $version,
		archive => "$tmp/$file",
	);
}

sub decompile_kit {
	return Genesis::Kit::Dev->new(kit(@_)->path);
}

subtest 'kit utilities' => sub {
	my $kit = kit('test', '1.0.0');
	throws_ok { $kit->kit_bug('buggy behavior') }
		qr{
			buggy \s+ behavior.*
			a \s+ bug \s+ in \s+ the \s+ test/1\.0\.0 \s+ kit.*
			file \s+ an \s+ issue \s+ at .* https://github\.com/.*/issues
		}six, "kit_bug() reports the pertinent details for a compiled kit";

	my $dev = decompile_kit('test', '1.0.0');
	throws_ok { $dev->kit_bug('buggy behavior') }
		qr{
			buggy \s+ behavior.*
			a \s+ bug \s+ in \s+ your \s+ dev/ \s+ kit.*
			contact .* author .* you
		}six, "kit_bug() reports the pertinent details for a dev kit";
};

subtest 'compiled kits' => sub {
	my $kit = kit(test => '0.0.1');
	# drwxr-xr-x  0 jhunt  staff       0 Apr  7 14:53 ./
	# -rw-r--r--  0 jhunt  staff     307 Apr  7 14:53 ./kit.yml
	# drwxr-xr-x  0 jhunt  staff       0 Apr  4 23:31 ./hooks/
	# -rw-r--r--  0 jhunt  staff      24 Apr  4 20:47 ./manifest.yml
	# -rwxr-xr-x  0 jhunt  staff     194 Apr  4 20:46 ./hooks/new
	# -rwxr-xr-x  0 jhunt  staff      40 Apr  4 20:47 ./hooks/blueprint

	cmp_deeply($kit->metadata, superhashof({
			name => 'simple',
		}), "a kit should be able to parse its metadata");
	cmp_deeply($kit->metadata, $kit->metadata,
		"subsequent calls to kit->metadata should return the same metadata");

	is($kit->id, "test/0.0.1", "compiled kits should report their ID properly");
	is($kit->name, "test", "compiled kits should be know their own name");
	is($kit->version, "0.0.1", "compiled kits should be know their own version");
	for my $f (qw(kit.yml manifest.yml hooks/new hooks/blueprint)) {
		ok(-f $kit->path($f), "[test-0.0.1] $f file should exist in compiled kit");
	}
	for my $d (qw(hooks)) {
		ok(-d $kit->path($d), "[test-0.0.1] $d/ should exist in compiled kit");
	}
	ok(!$kit->has_hook('secrets'), "[test-0.0.1] kit should not report hooks it doesn't have");
};

subtest 'dev kits' => sub {
	my $kit = kit(test => '0.0.1');
	my $dev = decompile_kit(test => '0.0.1');
	is($dev->name, "dev", "dev kits are all named 'dev'");
	is($dev->version, "latest", "dev kits are always at latest");
	is($dev->id, "(dev kit)", "dev kits should report their ID as dev, all the time");
	for my $f (qw(kit.yml manifest.yml hooks/new hooks/blueprint)) {
		ok(-f $dev->path($f), "[dev :: test-0.0.1] $f file should exist in dev kit");
	}
	for my $d (qw(hooks)) {
		ok(-d $dev->path($d), "[dev :: test-0.0.1] $d/ should exist in dev kit");
	}

	isnt($kit->path("kit.yml"), $dev->path("kit.yml"),
		"compiled-kit paths are not the same as dev-kit paths");

	## source yaml files, based on features:
	cmp_deeply([$kit->source_yaml_files()],
	           [re('\bmanifest.yml$')],
	           "simple kits without subkits should return base yaml files only");

	cmp_deeply([$kit->source_yaml_files(['bogus', 'features'])],
	           [$kit->source_yaml_files()],
	           "simple kits ignore features they don't know about");
};

subtest 'kit urls' => sub {
	my ($url, $version);

	lives_ok { ($url, $version) = Genesis::Kit->url('bosh') } "The BOSH kit has a valid download url";
	like $url, qr{^https://github.com/genesis-community/bosh-genesis-kit/releases/download/},
		"The BOSH kit url is on Github";

	lives_ok { ($url, $version) = Genesis::Kit->url('bosh', '0.2.0') } "The BOSH kit has a valid download url";
	is $version, '0.2.0', 'bosh-0.2.0 is v0.2.0';
	is $url, 'https://github.com/genesis-community/bosh-genesis-kit/releases/download/v0.2.0/bosh-0.2.0.tar.gz',
		"The BOSH kit url points to the 0.2.0 release";

	dies_ok { Genesis::Kit->url('bosh', '0.0.781') } "Non-existent versions of kits do not have download urls";
};

subtest 'version requirements' => sub {
	my $kit = kit(test => '1.2.3');
	local $Genesis::VERSION;

	$Genesis::VERSION = '0.0.1';
	ok !$kit->check_prereqs, 'v0.0.1 is too old for the t/src/simple kit prereq of 2.6.0';

	$Genesis::VERSION = '9.9.9';
	ok $kit->check_prereqs, 'v9.9.9 is new enough for the t/src/simple kit prereq of 2.6.0';

	$Genesis::VERSION = "dev";
	ok $kit->check_prereqs, 'dev versions are new enough for any kit prereq';
};

done_testing;