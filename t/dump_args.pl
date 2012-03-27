use strict;
use warnings;
use Data::Dumper;

local $Data::Dumper::Terse = 1;
local $Data::Dumper::Useqq = 1;

print Dumper(\@ARGV);
