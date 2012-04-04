use strict;
use warnings FATAL => 'all';
use Test::More tests => 1;

require_ok 'Win32::ShellQuote'
    or BAIL_OUT("Module failed to load!");

