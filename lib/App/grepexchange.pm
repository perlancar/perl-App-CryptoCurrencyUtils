package App::grepexchange;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use AppBase::Grep;
use Perinci::Sub::Util qw(gen_modified_sub);

our %SPEC;

gen_modified_sub(
    output_name => 'grep_exchange',
    base_name   => 'AppBase::Grep::grep',
    summary     => 'Grep cryptocurrency exchanges',
    description => <<'_',

Greps list of cryptocurrency exchanges from <pm:CryptoExchange::Catalog>, which
in turn gets its list from <https://coinmarketcap.com/>.

_
    remove_args => ['pattern'],
    modify_args => {
        regexps => sub {
            my $arg = shift;
            $arg->{pos} = 0;
            $arg->{greedy} = 1;
        },
        ignore_case => sub {
            my $arg = shift;
            $arg->{default} = 1;
        },
    },
    output_code => sub {
        require CryptoExchange::Catalog;

        my %args = @_;

        my @exchanges;
        my $cat = CryptoExchange::Catalog->new;
        for ($cat->all_data) {
            push @exchanges, "$_->{name}\n";
        }

        $args{_source} = sub {
            if (@exchanges) {
                return (shift(@exchanges), undef);
            } else {
                return;
            }
        };

        AppBase::Grep::grep(%args);
    },
);

1;
# ABSTRACT:
