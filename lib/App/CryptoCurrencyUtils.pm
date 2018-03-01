package App::CryptoCurrencyUtils;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

our %SPEC;

our %arg_coin = (
    coin => {
        schema => 'cryptocurrency::symbol_or_name*',
        req => 1,
        pos => 0,
    },
);

our %arg_coins = (
    coins => {
        'x.name.is_plural' => 1,
        'x.name.singular' => 'coin',
        schema => ['array*', of=>'cryptocurrency::symbol_or_name*'],
        req => 1,
        pos => 0,
        greedy => 1,
    },
);

our %arg_coins_opt = (
    coins => {
        'x.name.is_plural' => 1,
        'x.name.singular' => 'coin',
        schema => ['array*', of=>'cryptocurrency::symbol_or_name*'],
        pos => 0,
        greedy => 1,
    },
);

our %arg_exchange = (
    exchange => {
        schema => 'cryptoexchange::name*',
        req => 1,
        pos => 0,
    },
);

our %arg_exchanges = (
    exchanges => {
        'x.name.is_plural' => 1,
        'x.name.singular' => 'exchange',
        schema => ['array*', of=>'cryptoexchange::name*'],
        req => 1,
        pos => 0,
        greedy => 1,
    },
);

our %arg_convert = (
    convert => {
        schema => ['str*', in=>["AUD", "BRL", "CAD", "CHF", "CLP", "CNY", "CZK", "DKK", "EUR", "GBP", "HKD", "HUF", "IDR", "ILS", "INR", "JPY", "KRW", "MXN", "MYR", "NOK", "NZD", "PHP", "PKR", "PLN", "RUB", "SEK", "SGD", "THB", "TRY", "TWD", "ZAR"]],
    },
);

sub _get_json {
    require HTTP::Tiny;
    require JSON::MaybeXS;

    my ($url) = @_;

    my $res = HTTP::Tiny->new->get($url);
    return [$res->{status}, $res->{reason}] unless $res->{success};

    my $data;
    eval { $data = JSON::MaybeXS::decode_json($res->{content}) };
    return [500, "Can't decode JSON: $@"] if $@;

    [$res->{status}, $res->{reason}, $data];
}

sub _get_json_cmc {
    my $url = shift;
    my $res = _get_json($url);

    {
        last unless $res->[0] == 200;
        if (ref($res) eq 'HASH' && $res->{error}) {
            $res = [500, "Got error response from CMC API: $res->{error}"];
            last;
        }
    }
    $res;
}

$SPEC{coin_cmc_summary} = {
    v => 1.1,
    summary => "Get coin's CMC (coinmarketcap.com) summary",
    description => <<'_',

Currently retrieves https://api.coinmarketcap.com/v1/ticker/<coin-id>/ and
return the data in a table.

If no coins are specified, will return global data.

_
    args => {
        %arg_coins_opt,
        %arg_convert,
    },
};
sub coin_cmc_summary {
    require CryptoCurrency::Catalog;

    my %args = @_;

    my $cat = CryptoCurrency::Catalog->new;

    unless ($args{coins} && @{ $args{coins} }) {
        return global_cmc_summary();
    }

    my @rows;
  CURRENCY:
    for my $cur0 (@{ $args{coins} }) {

        my $cur;
        {
            eval { $cur = $cat->by_symbol($cur0) };
            last if $cur;
            eval { $cur = $cat->by_name($cur0) };
            last if $cur;
            warn "No such cryptocurrency symbol/name '$cur0'";
            next CURRENCY;
        }

        my $res = _get_json_cmc(
            "https://api.coinmarketcap.com/v1/ticker/$cur->{safename}/".
                ($args{convert} ? "?convert=$args{convert}" : ""));
        unless ($res->[0] == 200) {
            log_error("Can't get API result for $cur->{name}: $res->[0] - $res->[1]");
            next CURRENCY;
        }
        delete $res->[2][0]{id};
        push @rows, $res->[2][0];
    }

    my $resmeta = {
        'table.field_orders' => [qw/symbol name rank/, qr/^price_/ => sub { $_[0] cmp $_[1] }],
    };

    [200, "OK", \@rows, $resmeta];
}

$SPEC{global_cmc_summary} = {
    v => 1.1,
    summary => "Get global CMC (coinmarketcap.com) summary",
    description => <<'_',

Currently retrieves https://api.coinmarketcap.com/v1/ticker/<coin-id>/ and

_
    args => {
        %arg_convert,
    },
};
sub global_cmc_summary {
    my %args = @_;

    my $res = _get_json_cmc(
        "https://api.coinmarketcap.com/v1/global/".
            ($args{convert} ? "?convert=$args{convert}" : ""));
    unless ($res->[0] == 200) {
        return [500, "Can't get API result: $res->[0] - $res->[1]"];
    }

    [200, "OK", $res->[2]];
}

$SPEC{open_coin_cmc} = {
    v => 1.1,
    summary => "Open coin's CMC (coinmarketcap.com) currency page in the browser",
    args => {
        %arg_coins,
    },
};
sub open_coin_cmc {
    require CryptoCurrency::Catalog;
    my %args = @_;

    my $cat = CryptoCurrency::Catalog->new;

  CURRENCY:
    for my $cur0 (@{ $args{coins} }) {

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

$SPEC{open_coin_mno} = {
    v => 1.1,
    summary => "Open coin's MNO (masternodes.online) currency page in the browser",
    description => <<'_',

Currently does not perform any translation between CMC -> MNO currency code if
there is a difference.

_
    args => {
        %arg_coins,
    },
};
sub open_coin_mno {
    require CryptoCurrency::Catalog;
    require URI::Escape;

    my %args = @_;

    my $cat = CryptoCurrency::Catalog->new;

  CURRENCY:
    for my $cur0 (@{ $args{coins} }) {

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

$SPEC{open_exchange_cmc} = {
    v => 1.1,
    summary => "Open exchange's CMC (coinmarketcap.com) exchange page in the browser",
    args => {
        %arg_exchanges,
    },
};
sub open_exchange_cmc {
    require CryptoExchange::Catalog;
    my %args = @_;

    my $cat = CryptoExchange::Catalog->new;

  CURRENCY:
    for my $xchg0 (@{ $args{exchanges} }) {

        my $xchg;
        {
            eval { $xchg = $cat->by_name($xchg0) };
            last if $xchg;
            warn "No such cryptoexchange name '$xchg0'";
            next CURRENCY;
        }

        require Browser::Open;
        my $url = "https://coinmarketcap.com/exchanges/$xchg->{safename}/";
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
        symbols => {
            summary => 'Only list symbols',
            schema => 'true*',
        },
        safenames => {
            summary => 'Only list safenames',
            schema => 'true*',
        },
        names => {
            summary => 'Only list names',
            schema => 'true*',
        },
    },
    args_rels => {
        'choose_one' => [qw/symbols safenames names/],
    },
};
sub list_coins {
    require CryptoCurrency::Catalog;

    my %args = @_;

    if ($args{symbols}) {
        [200, "OK", [map {$_->{symbol}} CryptoCurrency::Catalog->new->all_data]];
    } elsif ($args{safenames}) {
        [200, "OK", [map {$_->{safename}} CryptoCurrency::Catalog->new->all_data]];
    } elsif ($args{names}) {
        [200, "OK", [map {$_->{name}} CryptoCurrency::Catalog->new->all_data]];
    } else {
        [200, "OK", [CryptoCurrency::Catalog->new->all_data]];
    }
}


$SPEC{list_exchanges} = {
    v => 1.1,
    summary => "List cryptocurrency exchanges",
    description => <<'_',

This utility lists cryptocurrency exchanges from <pm:CryptoExchange::Catalog>,
which in turn gets its list from <https://coinmarketcap.com/>.

_
    args => {
    },
};
sub list_exchanges {
    require CryptoExchange::Catalog;

    [200, "OK", [CryptoExchange::Catalog->new->all_data]];
}

$SPEC{list_cmc_coins} = {
    v => 1.1,
    summary => "List of all coins listed on coinmarketcap.com (CMC) ".
        "along with their marketcaps, ranks, etc",
    description => <<'_',

This utility basically parses <https://coinmarketcap.com/all/views/all/> into
table data.

_
    args => {
    },
};
sub list_cmc_coins {
    require HTTP::Tiny;

    my $res = HTTP::Tiny->new->get("https://coinmarketcap.com/all/views/all/");
    return [$res->{status}, $res->{reason}] unless $res->{success};

    my @coins;

    # we capture the records first to speed up otherwise-glacial matching
    my @trs;
    while ($res->{content} =~ m!(<tr \s id="id-[\w-]+".+?</tr>)!gsx) {
        push @trs, $1;
    }
    #say "D:found ", scalar(@trs), " coins";

    my $i = 0;
    for my $tr (@trs) {
        $i++;
        $tr =~
            m!<tr \s id="id-(?<safename>[\w-]+)"[^>]*>.+?
              <td \s class="text-center">\s*(?<rank>\d+)\s*</td>.+?
              <td \s class="[^"]*?col-symbol">(?<symbol>[^<]+)<.+?
              <td \s class="[^"]*?market-cap[^"]*" \s data-usd="(?<mktcap_usd>[^"]+)" \s data-btc="(?<mktcap_btc>[^"]+)".+?
              <a \s href="[^"]+" \s class="price" \s data-usd="(?<price_usd>[^"]+)" \s data-btc="(?<price_btc>[^"]+)".+?
              \s data-supply="(?<supply>[^"]+)".+?
              <a \s href="[^"]+" \s class="volume" \s data-usd="(?<volume_usd>[^"]+)" \s data-btc="(?<volume_btc>[^"]+)".+?
             !sx
                 or die "Can't parse row #$i";
        push @coins, {%+};
    }

    my $resmeta = {
        'table.fields'       => [qw/rank safename symbol mktcap_usd mktcap_btc price_usd price_btc supply volume_usd volume_btc/],
        #'table.field_aligns' => [qw/left left     left   right      right     right     right     right  right      right/], # ugh, makes rendering so slow
    };
    [200, "OK", \@coins, $resmeta];
}

1;
# ABSTRACT: CLI utilities related to cryptocurrencies

=head1 DESCRIPTION

This distribution contains the following CLI utilities:

# INSERT_EXECS_LIST


=head1 SEE ALSO

=cut
