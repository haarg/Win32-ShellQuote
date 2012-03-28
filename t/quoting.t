use strict;
use warnings;
use Test::More;
use File::Basename ();
use File::Spec;
use Win32::ShellQuote qw(:all);
use Capture::Tiny qw(capture);
use Data::Dumper;
use File::Temp;
use File::Copy ();

sub dd {
    my $string = shift;
    local $Data::Dumper::Terse = 1;
    local $Data::Dumper::Useqq
        = grep { /[\r\n']/ } ref $string ? @$string : $string;
    my $out = Data::Dumper::Dumper($string);
    chomp $out;
    return $out;
}

my $dumper_orig = File::Spec->rel2abs(
    File::Spec->catfile(File::Basename::dirname(__FILE__), 'dump_args.pl')
);

my @test_strings = (
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
    '%a%',
    '%a b',
    '\%a b',
    ' & help & ',
    ' > out',
    ' | welp',
    '" | welp"',
    '\" | welp',
    "",
    "\n",
    "a\nb",
    "a\rb",

# from EUMM.  Not all meant to be used like this, but still good test material
    q{print "foo'o", ' bar"ar'},
    q{$PATH = 'foo'; print $PATH},
    q{print 'foo'},
    q{print " \" "},
    q{print " < \" "},
    q{print " \" < "},
    q{print " < \"\" < \" < \" < "},
    q{print " < \" | \" < | \" < \" < "},

    q{print q[ &<>^|()@ ! ]}, [],  q{ &<>^|()@ ! },
    q{print q[ &<>^|@()!"&<>^|@()! ]},
    q{print q[ "&<>^|@() !"&<>^|@() !" ]},
    q{print q[ "C:\TEST A\" ]},
    q{print q[ "C:\TEST %&^ A\" ]},

);

push @test_strings, make_random_strings( 20 );

my $tmpdir = File::Temp::tempdir();

my $test_dir = File::Spec->catdir($tmpdir, "dir with spaces");
mkdir $test_dir;

my $test_dumper = File::Spec->catfile($test_dir, 'dumper with spaces.pl');
File::Copy::cp($dumper_orig, $test_dumper);

for my $dumper ($dumper_orig, $test_dumper) {
    note "testing with $dumper";
    for my $string ( @test_strings ) {
        subtest "string: " . dd( $string ) => sub {
            {
                my $out = eval capture { system quote_as_list($^X, $dumper, $string, $string) };
                is scalar @$out, 2, 'correct # of args for ' . dd($string) . ' as list';
                is $out->[0], $string, 'roundtrip ' . dd($string) . ' as list';
                is $out->[0], $out->[1], 'both args match for ' . dd($string) . ' as list';
            }

            {
                my $out = eval capture { system quote_as_string($^X, $dumper, $string, $string) };
                is scalar @$out, 2, 'correct # of args for ' . dd($string) . ' as string';
                is $out->[0], $string, 'roundtrip ' . dd($string) . ' as string';
                is $out->[0], $out->[1], 'both args match for ' . dd($string) . ' as string';
            }
        };
    }
}

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
