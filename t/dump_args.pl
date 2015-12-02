use strict;
use warnings;
use File::Basename qw(dirname);
use lib dirname(__FILE__) . '/lib';
use TestUtil;

print dd(\@ARGV);

1;
