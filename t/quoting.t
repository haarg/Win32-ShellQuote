use strict;
use warnings FATAL => 'all';
use Test::More $^O eq 'MSWin32' ? ()
  : (skip_all => "can only test for valid unquoting on Win32");

use File::Basename qw(dirname);
use File::Spec::Functions qw(catfile catdir rel2abs);
use Win32::ShellQuote qw(:all);
use File::Temp qw(tempdir);
use File::Copy qw(copy);
use Cwd ();
use lib 't/lib';
use TestUtil;

my $dumper_orig = rel2abs(catfile(dirname(__FILE__), 'dump_args.pl'));

my $cwd = Cwd::cwd;
my $guard = guard { chdir $cwd };

my $tmpdir = tempdir CLEANUP => 1;
chdir $tmpdir;

my $test_dir = catdir $tmpdir, "dir with spaces";
mkdir $test_dir;

my $test_dumper = catfile $test_dir, 'dumper with spaces.pl';
copy $dumper_orig, $test_dumper;

sub test_params {
    my @test_strings = ref $_[0] ? @{ $_[0] } : @_;
    subtest "string: " . dd( \@test_strings ) => sub {
        plan tests => 2*2*3*3;
        for my $perl ([1, $^X], [0, 'IF', 'NOT', 'foo==bar', $^X]) {
            my ($pass, @perl) = @$perl;
            my $cmp = $pass ? 'eq' : 'ne';
            note "using perl: @perl";

        for my $dumper ($dumper_orig, $test_dumper) {
            note "using dumper: $dumper";

        for my $params ( [@test_strings], [@test_strings, '>out'], [@test_strings, '%']  ) {
            my $name = ($pass ? '' : "don't ") . 'roundtrip ' . dd($params) . ($pass ? '' : ' with bad perl path');

            eval {
                my $out = capture { system quote_system_list(@perl, $dumper, @$params) };
                cmp_ok $out, $cmp, dd $params, "$name as list";
            };
            if (my $e = $@) {
                fail "$name as list";
                chomp $e;
                diag $e;
            }

            TODO: {
                local $TODO = 'forced to use cmd, but using non-escapable characters'
                    if Win32::ShellQuote::_has_shell_metachars(quote_native(@$params))
                    && grep { /[\r\n\0]/ } @$params;
                eval {
                    my $out = capture { system quote_system_string(@perl, $dumper, @$params) };
                    cmp_ok $out, $cmp, dd $params, "$name as string";
                };
                if (my $e = $@) {
                    fail "$name as string";
                    chomp $e;
                    diag $e;
                }
            }

            TODO: {
                local $TODO = "newlines don't play well with cmd"
                    if grep { /[\r\n\0]/ } @$params;
                eval {
                    my $out = capture { system quote_system_cmd(@perl, $dumper, @$params) };
                    cmp_ok $out, $cmp, dd $params, "$name as cmd";
                };
                if (my $e = $@) {
                    fail "$name as cmd";
                    chomp $e;
                    diag $e;
                }
            }
        } } }
    };
}

test_params($_) for (
    'a',
    'a b',
    '"a b"',
    '"a" b',
    '"a" "b"',
    '\'a\'',
    '"a',
    '"a b',
    '\'a',
    '\'a b',
    '\'a b"',
    '\\a',
    '\\"a',
    '\\ a',
    '\\ "\' a',
    [ '\\ "\' a', ">\\"],
    '%a%',
    '%a b',
    '\%a b',
    ' & help & ',
    ' > out',
    ' | welp',
    '" | welp"',
    '\" | welp',
    "",

# from EUMM.  Not all meant to be used like this, but still good test material
    q{print "foo'o", ' bar"ar'},
    q{$PATH = 'foo'; print $PATH},
    q{print 'foo'},
    q{print " \" "},
    q{print " < \" "},
    q{print " \" < "},
    q{print " < \"\" < \" < \" < "},
    q{print " < \" | \" < | \" < \" < "},

    q{print q[ &<>^|()@ ! ]},
    q{print q[ &<>^|@()!"&<>^|@()! ]},
    q{print q[ "&<>^|@() !"&<>^|@() !" ]},
    q{print q[ "C:\TEST A\" ]},
    q{print q[ "C:\TEST %&^ A\" ]},

    "\n",
    "a\nb",
    "a\rb",
    "a\nb > welp",
    "a > welp\n219",
    "a\"b\nc",

    "a\fb",
    "a\x0bb",
    "a\x{85}b",

    $ENV{AUTHOR_TESTING} ? make_random_strings( 20 ) : (),
);

done_testing;
