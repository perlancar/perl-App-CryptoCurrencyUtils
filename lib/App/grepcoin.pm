package App::grepcoin;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use AppBase::Grep;
use Perinci::Sub::Util qw(gen_modified_sub);

our %SPEC;

gen_modified_sub(
    output_name => 'grep_coin',
    base_name   => 'AppBase::Grep::grep',
    summary     => 'Grep cryptocurrency coins',
    description => <<'_',

Greps list of coins from <pm:CryptoCurrency::Catalog>, which in turn gets its
list from <https://coinmarketcap.com/>.

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
        require CryptoCurrency::Catalog;

        my %args = @_;

        my @coins;
        my $cat = CryptoCurrency::Catalog->new;
        for ($cat->all_data) {
            push @coins, "$_->{name} ($_->{code})\n";
        }

        $args{_source} = sub {
            if (@coins) {
                return (shift(@coins), undef);
            } else {
                return;
            }
        };

        AppBase::Grep::grep(%args);
    },
);

1;
# ABSTRACT:
