use strict;
use warnings;
use Data::Dumper ();

sub dd ($) {
  my $params = shift;;
  local $Data::Dumper::Indent = 0;
  local $Data::Dumper::Terse = 1;
  local $Data::Dumper::Useqq = 1;
  local $Data::Dumper::Sortkeys = 1;
  local $Data::Dumper::Useqq = grep { /[\r\n']/ } @$params;

  my $out = Data::Dumper::Dumper($params);
  chomp $out;
  return $out;
}

if (!caller) {
  print dd(\@ARGV);
}
1;
