use strict;
use warnings FATAL => 'all';
use Test::More;
use File::Basename ();
use File::Spec;
use Win32::ShellQuote qw(:all);
use Capture::Tiny qw(capture_merged);
use File::Temp;
use File::Copy ();
use Cwd ();

if ($^O ne 'MSWin32') {
    plan skip_all => "can only test for valid quoting on Win32";
}

my $dumper_orig;

BEGIN {
    $dumper_orig = File::Spec->rel2abs(
      File::Spec->catfile(File::Basename::dirname(__FILE__), 'dump_args.pl'));
    require $dumper_orig;
}

sub TestGuard::DESTROY { $_[0]->(); }
my $cwd = Cwd::cwd;
my $guard = bless sub { chdir $cwd }, 'TestGuard';

my $tmpdir = File::Temp::tempdir(CLEANUP => 1);
chdir $tmpdir;

my $test_dir = File::Spec->catdir($tmpdir, "dir with spaces");
mkdir $test_dir;

my $test_dumper = File::Spec->catfile($test_dir, 'dumper with spaces.pl');
File::Copy::cp($dumper_orig, $test_dumper);

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
                my $out = capture_merged { system quote_system_list(@perl, $dumper, @$params) };
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
                    my $out = capture_merged { system quote_system_string(@perl, $dumper, @$params) };
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
                    my $out = capture_merged { system quote_system_cmd(@perl, $dumper, @$params) };
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

sub make_random_strings {
    my ( $string_count ) = @_;

    my @charsets = map [ map chr, @{$_} ], [ 32 .. 126 ], [ 10, 13, 32 .. 126 ], [ 1 .. 127 ], [ 1 .. 255 ];

    my @strings = map make_random_string( $charsets[ int rand $#charsets + 1 ] ), 0 .. $string_count;

    return @strings;
}

sub make_random_string {
    my ( $chars ) = @_;

    my $string = join '', map $chars->[ rand $#$chars + 1 ], 1 .. int rand 70;

    return $string;
}
