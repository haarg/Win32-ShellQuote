use strict;
use warnings FATAL => 'all';
use Test::More;
use File::Basename ();
use File::Spec;
use Win32::ShellQuote qw(:all);
use Capture::Tiny qw(capture capture_stdout);
use Data::Dumper ();
use File::Temp;
use File::Copy ();
use Try::Tiny;

if ($^O ne 'MSWin32') {
    plan skip_all => "can only test for valid quoting on Win32";
}

my $dumper_orig = File::Spec->rel2abs(
    File::Spec->catfile(File::Basename::dirname(__FILE__), 'dump_args.pl')
);

my $tmpdir = File::Temp::tempdir(CLEANUP => 1);

my $test_dir = File::Spec->catdir($tmpdir, "dir with spaces");
mkdir $test_dir;

my $test_dumper = File::Spec->catfile($test_dir, 'dumper with spaces.pl');
File::Copy::cp($dumper_orig, $test_dumper);

sub test_params {
    my @test_strings = ref $_[0] ? @{ $_[0] } : @_;
    subtest "string: " . dd( \@test_strings ) => sub {
        plan tests => 18;
        for my $dumper ($dumper_orig, $test_dumper) {
            for my $params ( [@test_strings], [@test_strings, '>out'], [@test_strings, '%']  ) {
                try {
                    my $out = eval capture_stdout { system quote_system_list($^X, $dumper, @$params) };
                    is_deeply $out, $params, 'roundtrip ' . dd($params) . ' as list';
                }
                catch {
                    fail 'roundtrip ' . dd($params) . ' as list';
                    chomp;
                    diag $_;
                };

                TODO: {
                    local $TODO = 'forced to use cmd, but using non-escapable characters'
                        if Win32::ShellQuote::_has_shell_metachars(quote_native(@$params))
                        && grep { /[\r\n\0]/ } @$params;
                    try {
                        my $out = eval capture_stdout { system quote_system_string($^X, $dumper, @$params) };
                        is_deeply $out, $params, 'roundtrip ' . dd($params) . ' as string';
                    }
                    catch {
                        fail 'roundtrip ' . dd($params) . ' as string';
                        chomp;
                        diag $_;
                    };
                }

                TODO: {
                    local $TODO = "newlines don't play well with cmd"
                        if grep { /[\r\n\0]/ } @$params;
                    try {
                        my $out = eval capture_stdout { system quote_system_cmd($^X, $dumper, @$params) };
                        is_deeply $out, $params, 'roundtrip ' . dd($params) . ' as cmd';
                    }
                    catch {
                        fail 'roundtrip ' . dd($params) . ' as cmd';
                        chomp;
                        diag $_;
                    };

                }
            }
        }
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

sub dd {
    my $string = shift;
    local $Data::Dumper::Indent = 0;
    local $Data::Dumper::Terse = 1;
    local $Data::Dumper::Useqq
        = grep { /[\r\n']/ } ref $string ? @$string : $string;
    my $out = Data::Dumper::Dumper($string);
    chomp $out;
    return $out;
}

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
