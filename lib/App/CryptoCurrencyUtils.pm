package App::CryptoCurrencyUtils;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

our %SPEC;

$SPEC{coin_cmc} = {
    v => 1.1,
    summary => "Go to coin's CMC (coinmarketcap.com) currency page",
    args => {
        symbol_or_name => {
            schema => 'cryptocurrency::symbol_or_name*',
            req => 1,
            pos => 0,
        },
    },
};
sub coin_cmc {
    require CryptoCurrency::Catalog;
    my %args = @_;

    my $cat = CryptoCurrency::Catalog->new;

    my $cur0 = $args{symbol_or_name}
        or return [400, "Please specify symbol/name"];

    my $cur;
    {
        eval { $cur = $cat->by_symbol($cur0) };
        last if $cur;
        eval { $cur = $cat->by_name($cur0) };
        last if $cur;
        return [404, "No such cryptocurrency symbol/name"];
    }

    require Browser::Open;
    my $err = Browser::Open::open_browser(
        "https://coinmarketcap.com/currencies/$cur->{safename}/");
    return [500, "Can't open browser"] if $err;
    [200];
}

1;
# ABSTRACT: CLI utilities related to cryptocurrencies

=head1 DESCRIPTION

This distribution contains the following CLI utilities:

# INSERT_EXECS_LIST


=head1 SEE ALSO

L<App::CoinMarketCapUtils>

=cut
