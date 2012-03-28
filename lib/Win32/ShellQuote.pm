package Win32::ShellQuote;
use strict;
use warnings;
use Exporter qw(import);

our @EXPORT_OK = qw(quote_as_list quote_as_string quote_literal);
our %EXPORT_TAGS = (all => [@EXPORT_OK]);

sub quote_as_list {
    my @args = @_;

    return map { quote_literal($_) } @args;
}

sub quote_as_string {
    my @args = @_;

    my $args = join ' ', quote_as_list(@args);

    if (_has_shell_metachars($args)) {
        # cmd.exe treats quotes differently from standard
        # argument parsing. just escape everything using ^.
        $args = cmd_escape($args);
    }
    return $args;
}

sub cmd_escape {
    my $string = shift;
    $string =~ s/([()%!^"<>&|])/^$1/g;
    return $string;
}

sub quote_literal {
    my ($text) = @_;

    # basic argument quoting.  uses backslashes and quotes to escape
    # everything.
    if ($text ne '' && $text !~ /[ \t\n\v"]/) {
        # no quoting needed
    }
    else {
        my @text = split '', $text;
        $text = q{"};
        for (my $i = 0; ; $i++) {
            my $bs_count = 0;
            while ( $i < @text && $text[$i] eq "\\" ) {
                $i++;
                $bs_count++;
            }
            if ($i > $#text) {
                $text .= "\\" x ($bs_count * 2);
                last;
            }
            elsif ($text[$i] eq q{"}) {
                $text .= "\\" x ($bs_count * 2 + 1);
            }
            else {
                $text .= "\\" x $bs_count;
            }
            $text .= $text[$i];
        }
        $text .= q{"};
    }

    return $text;
}

# direct port of code from win32.c
sub _has_shell_metachars {
    my $string = shift;
    my $inquote = 0;
    my $quote = '';

    my @string = split '', $string;
    for my $char (@string) {
        if ($char eq q{%}) {
            return 1;
        }
        elsif ($char eq q{'} || $char eq q{"}) {
            if ($inquote) {
                if ($char eq $quote) {
                    $inquote = 0;
                    $quote = '';
                }
            }
            else {
                $quote = $char;
                $inquote++;
            }
        }
        elsif ($char eq q{<} || $char eq q{>} || $char eq q{|}) {
            if ( ! $inquote) {
                return 1;
            }
        }
    }
    return;
}

1;
