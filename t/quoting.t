use strict;
use warnings FATAL => 'all';
use Test::More;

use File::Basename qw(dirname);
use File::Spec::Functions qw(catfile catdir rel2abs);
use Win32::ShellQuote qw(:all);
use File::Temp qw(tempdir);
use File::Copy qw(copy);
use Cwd ();
use lib 't/lib';
use TestUtil;

for my $test (
  {
    args    => [ qq[a] ],
    cmd     => qq[^"a^"],
    native  => qq["a"],
    system  => qq["a"],
  },
  {
    args    => [ qq[a b] ],
    cmd     => qq[^"a b^"],
    native  => qq["a b"],
    system  => qq["a b"],
  },
  {
    args    => [ qq["a b"] ],
    cmd     => qq[^"\\^"a b\\^"^"],
    native  => qq["\\"a b\\""],
    system  => qq["\\"a b\\""],
  },
  {
    args    => [ qq["a" b] ],
    cmd     => qq[^"\\^"a\\^" b^"],
    native  => qq["\\"a\\" b"],
    system  => qq["\\"a\\" b"],
  },
  {
    args    => [ qq["a" "b"] ],
    cmd     => qq[^"\\^"a\\^" \\^"b\\^"^"],
    native  => qq["\\"a\\" \\"b\\""],
    system  => qq["\\"a\\" \\"b\\""],
  },
  {
    args    => [ qq['a'] ],
    cmd     => qq[^"'a'^"],
    native  => qq["'a'"],
    system  => qq["'a'"],
  },
  {
    args    => [ qq["a] ],
    cmd     => qq[^"\\^"a^"],
    native  => qq["\\"a"],
    system  => qq["\\"a"],
  },
  {
    args    => [ qq["a b] ],
    cmd     => qq[^"\\^"a b^"],
    native  => qq["\\"a b"],
    system  => qq["\\"a b"],
  },
  {
    args    => [ qq['a] ],
    cmd     => qq[^"'a^"],
    native  => qq["'a"],
    system  => qq["'a"],
  },
  {
    args    => [ qq['a b] ],
    cmd     => qq[^"'a b^"],
    native  => qq["'a b"],
    system  => qq["'a b"],
  },
  {
    args    => [ qq['a b"] ],
    cmd     => qq[^"'a b\\^"^"],
    native  => qq["'a b\\""],
    system  => qq["'a b\\""],
  },
  {
    args    => [ qq[\\a] ],
    cmd     => qq[^"\\a^"],
    native  => qq["\\a"],
    system  => qq["\\a"],
  },
  {
    args    => [ qq[\\"a] ],
    cmd     => qq[^"\\\\\\^"a^"],
    native  => qq["\\\\\\"a"],
    system  => qq["\\\\\\"a"],
  },
  {
    args    => [ qq[\\ a] ],
    cmd     => qq[^"\\ a^"],
    native  => qq["\\ a"],
    system  => qq["\\ a"],
  },
  {
    args    => [ qq[\\ "' a] ],
    cmd     => qq[^"\\ \\^"' a^"],
    native  => qq["\\ \\"' a"],
    system  => qq["\\ \\"' a"],
  },
  {
    args    => [ qq[\\ "' a], qq[>\\] ],
    cmd     => qq[^"\\ \\^"' a^" ^"^>\\\\^"],
    native  => qq["\\ \\"' a" ">\\\\"],
    system  => qq[^"\\ \\^"' a^" ^"^>\\\\^"],
  },
  {
    args    => [ qq[%a%] ],
    cmd     => qq[^"^%a^%^"],
    native  => qq["%a%"],
    system  => qq[^"^%a^%^"],
  },
  {
    args    => [ qq[%a b] ],
    cmd     => qq[^"^%a b^"],
    native  => qq["%a b"],
    system  => qq[^"^%a b^"],
  },
  {
    args    => [ qq[\\%a b] ],
    cmd     => qq[^"\\^%a b^"],
    native  => qq["\\%a b"],
    system  => qq[^"\\^%a b^"],
  },
  {
    args    => [ qq[ & help & ] ],
    cmd     => qq[^" ^& help ^& ^"],
    native  => qq[" & help & "],
    system  => qq[" & help & "],
  },
  {
    args    => [ qq[ > out] ],
    cmd     => qq[^" ^> out^"],
    native  => qq[" > out"],
    system  => qq[" > out"],
  },
  {
    args    => [ qq[ | welp] ],
    cmd     => qq[^" ^| welp^"],
    native  => qq[" | welp"],
    system  => qq[" | welp"],
  },
  {
    args    => [ qq[" | welp"] ],
    cmd     => qq[^"\\^" ^| welp\\^"^"],
    native  => qq["\\" | welp\\""],
    system  => qq[^"\\^" ^| welp\\^"^"],
  },
  {
    args    => [ qq[\\" | welp] ],
    cmd     => qq[^"\\\\\\^" ^| welp^"],
    native  => qq["\\\\\\" | welp"],
    system  => qq[^"\\\\\\^" ^| welp^"],
  },
  {
    args    => [ qq[] ],
    cmd     => qq[^"^"],
    native  => qq[""],
    system  => qq[""],
  },
  {
    args    => [ qq[print "foo'o", ' bar"ar'] ],
    cmd     => qq[^"print \\^"foo'o\\^", ' bar\\^"ar'^"],
    native  => qq["print \\"foo'o\\", ' bar\\"ar'"],
    system  => qq["print \\"foo'o\\", ' bar\\"ar'"],
  },
  {
    args    => [ qq[\$PATH = 'foo'; print \$PATH] ],
    cmd     => qq[^"\$PATH = 'foo'; print \$PATH^"],
    native  => qq["\$PATH = 'foo'; print \$PATH"],
    system  => qq["\$PATH = 'foo'; print \$PATH"],
  },
  {
    args    => [ qq[print 'foo'] ],
    cmd     => qq[^"print 'foo'^"],
    native  => qq["print 'foo'"],
    system  => qq["print 'foo'"],
  },
  {
    args    => [ qq[print " \\" "] ],
    cmd     => qq[^"print \\^" \\\\\\^" \\^"^"],
    native  => qq["print \\" \\\\\\" \\""],
    system  => qq["print \\" \\\\\\" \\""],
  },
  {
    args    => [ qq[print " < \\" "] ],
    cmd     => qq[^"print \\^" ^< \\\\\\^" \\^"^"],
    native  => qq["print \\" < \\\\\\" \\""],
    system  => qq[^"print \\^" ^< \\\\\\^" \\^"^"],
  },
  {
    args    => [ qq[print " \\" < "] ],
    cmd     => qq[^"print \\^" \\\\\\^" ^< \\^"^"],
    native  => qq["print \\" \\\\\\" < \\""],
    system  => qq[^"print \\^" \\\\\\^" ^< \\^"^"],
  },
  {
    args    => [ qq[print " < \\"\\" < \\" < \\" < "] ],
    cmd     => qq[^"print \\^" ^< \\\\\\^"\\\\\\^" ^< \\\\\\^" ^< \\\\\\^" ^< \\^"^"],
    native  => qq["print \\" < \\\\\\"\\\\\\" < \\\\\\" < \\\\\\" < \\""],
    system  => qq[^"print \\^" ^< \\\\\\^"\\\\\\^" ^< \\\\\\^" ^< \\\\\\^" ^< \\^"^"],
  },
  {
    args    => [ qq[print " < \\" | \\" < | \\" < \\" < "] ],
    cmd     => qq[^"print \\^" ^< \\\\\\^" ^| \\\\\\^" ^< ^| \\\\\\^" ^< \\\\\\^" ^< \\^"^"],
    native  => qq["print \\" < \\\\\\" | \\\\\\" < | \\\\\\" < \\\\\\" < \\""],
    system  => qq[^"print \\^" ^< \\\\\\^" ^| \\\\\\^" ^< ^| \\\\\\^" ^< \\\\\\^" ^< \\^"^"],
  },
  {
    args    => [ qq[print q[ &<>^|()\@ ! ]] ],
    cmd     => qq[^"print q[ ^&^<^>^^^|^(^)\@ ^! ]^"],
    native  => qq["print q[ &<>^|()\@ ! ]"],
    system  => qq["print q[ &<>^|()\@ ! ]"],
  },
  {
    args    => [ qq[print q[ &<>^|\@()!"&<>^|\@()! ]] ],
    cmd     => qq[^"print q[ ^&^<^>^^^|\@^(^)^!\\^"^&^<^>^^^|\@^(^)^! ]^"],
    native  => qq["print q[ &<>^|\@()!\\"&<>^|\@()! ]"],
    system  => qq[^"print q[ ^&^<^>^^^|\@^(^)^!\\^"^&^<^>^^^|\@^(^)^! ]^"],
  },
  {
    args    => [ qq[print q[ "&<>^|\@() !"&<>^|\@() !" ]] ],
    cmd     => qq[^"print q[ \\^"^&^<^>^^^|\@^(^) ^!\\^"^&^<^>^^^|\@^(^) ^!\\^" ]^"],
    native  => qq["print q[ \\"&<>^|\@() !\\"&<>^|\@() !\\" ]"],
    system  => qq[^"print q[ \\^"^&^<^>^^^|\@^(^) ^!\\^"^&^<^>^^^|\@^(^) ^!\\^" ]^"],
  },
  {
    args    => [ qq[print q[ "C:\\TEST A\\" ]] ],
    cmd     => qq[^"print q[ \\^"C:\\TEST A\\\\\\^" ]^"],
    native  => qq["print q[ \\"C:\\TEST A\\\\\\" ]"],
    system  => qq["print q[ \\"C:\\TEST A\\\\\\" ]"],
  },
  {
    args    => [ qq[print q[ "C:\\TEST %&^ A\\" ]] ],
    cmd     => qq[^"print q[ \\^"C:\\TEST ^%^&^^ A\\\\\\^" ]^"],
    native  => qq["print q[ \\"C:\\TEST %&^ A\\\\\\" ]"],
    system  => qq[^"print q[ \\^"C:\\TEST ^%^&^^ A\\\\\\^" ]^"],
  },
  {
    args    => [ qq[\n] ],
    cmd     => undef,
    native  => qq["\n"],
    system  => qq["\n"],
  },
  {
    args    => [ qq[a\nb] ],
    cmd     => undef,
    native  => qq["a\nb"],
    system  => qq["a\nb"],
  },
  {
    args    => [ qq[a\rb] ],
    cmd     => undef,
    native  => qq["a\rb"],
    system  => qq["a\rb"],
  },
  {
    args    => [ qq[a\nb > welp] ],
    cmd     => undef,
    native  => qq["a\nb > welp"],
    system  => undef
  },
  {
    args    => [ qq[a > welp\n219] ],
    cmd     => undef,
    native  => qq["a > welp\n219"],
    system  => undef
  },
  {
    args    => [ qq[a"b\nc] ],
    cmd     => undef,
    native  => qq["a\\"b\nc"],
    system  => qq["a\\"b\nc"],
  },
  {
    args    => [ qq[a\fb] ],
    cmd     => qq[^"a\fb^"],
    native  => qq["a\fb"],
    system  => qq["a\fb"],
  },
  {
    args    => [ qq[a\x0bb] ],
    cmd     => qq[^"a\x0bb^"],
    native  => qq["a\x0bb"],
    system  => qq["a\x0bb"],
  },
  {
    args    => [ qq[a\x{85}b] ],
    cmd     => qq[^"a\x{85}b^"],
    native  => qq["a\x{85}b"],
    system  => qq["a\x{85}b"],
  }
) {
  my $name = dd($test->{args});
  my $native  = eval { quote_native(        @{ $test->{args} } ) };
  my $cmd     = eval { quote_cmd(           @{ $test->{args} } ) };
  my $system  = eval { quote_system_string( @{ $test->{args} } ) };

  is $native, $test->{native}, "$name as native";
  is $cmd,    $test->{cmd},    "$name as cmd";
  is $system, $test->{system}, "$name as system";
  #TODO: AUTHOR_TESTING to verify valid data
}
done_testing;
