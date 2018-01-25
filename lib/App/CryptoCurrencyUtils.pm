package App::CryptoCurrencyUtils;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

our %SPEC;

our %arg_symbol_or_name = (
    symbol_or_name => {
        schema => 'cryptocurrency::symbol_or_name*',
        req => 1,
        pos => 0,
    },
);

our %arg_symbols_or_names = (
    symbols_or_names => {
        'x.name.is_plural' => 1,
        'x.name.singular' => 'symbol_or_name',
        schema => ['array*', of=>'cryptocurrency::symbol_or_name*'],
        req => 1,
        pos => 0,
        greedy => 1,
    },
);

$SPEC{coin_cmc} = {
    v => 1.1,
    summary => "Go to coin's CMC (coinmarketcap.com) currency page",
    args => {
        %arg_symbols_or_names,
    },
};
sub coin_cmc {
    require CryptoCurrency::Catalog;
    my %args = @_;

    my $cat = CryptoCurrency::Catalog->new;

  CURRENCY:
    for my $cur0 (@{ $args{symbols_or_names} }) {

        my $cur;
        {
            eval { $cur = $cat->by_symbol($cur0) };
            last if $cur;
            eval { $cur = $cat->by_name($cur0) };
            last if $cur;
            warn "No such cryptocurrency symbol/name '$cur0'";
            next CURRENCY;
        }

        require Browser::Open;
        my $url = "https://coinmarketcap.com/currencies/$cur->{safename}/";
        my $err = Browser::Open::open_browser($url);
        return [500, "Can't open browser for '$url'"] if $err;
    }
    [200];
}

$SPEC{coin_mno} = {
    v => 1.1,
    summary => "Go to coin's MNO (masternodes.online) currency page",
    description => <<'_',

Currently does not perform any translation between CMC -> MNO currency code if
there is a difference.

_
    args => {
        %arg_symbols_or_names,
    },
};
sub coin_mno {
    require CryptoCurrency::Catalog;
    require URI::Escape;

    my %args = @_;

    my $cat = CryptoCurrency::Catalog->new;

  CURRENCY:
    for my $cur0 (@{ $args{symbols_or_names} }) {

        my $cur;
        {
            eval { $cur = $cat->by_symbol($cur0) };
            last if $cur;
            eval { $cur = $cat->by_name($cur0) };
            last if $cur;
            warn "No such cryptocurrency symbol/name '$cur0'";
            next CURRENCY;
        }

        require Browser::Open;
        my $url = "https://masternodes.online/currencies/" .
            URI::Escape::uri_escape($cur->{symbol})."/";
        my $err = Browser::Open::open_browser($url);
        return [500, "Can't open browser for '$url'"] if $err;
    }
    [200];
}

$SPEC{list_coins} = {
    v => 1.1,
    summary => "List cryptocurrency coins",
    description => <<'_',

This utility lists coins from <pm:CryptoCurrency::Catalog>, which in turn gets
its list from <https://coinmarketcap.com/>.

_
    args => {
    },
};
sub list_coins {
    require CryptoCurrency::Catalog;

    [200, "OK", [CryptoCurrency::Catalog->new->all_data]];
}

1;
# ABSTRACT: CLI utilities related to cryptocurrencies

=head1 DESCRIPTION

This distribution contains the following CLI utilities:

# INSERT_EXECS_LIST


=head1 SEE ALSO

=cut
