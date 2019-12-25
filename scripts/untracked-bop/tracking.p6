#!/usr/bin/env perl6

use HTTP::UserAgent;
use JSON::Fast;

for 'LL613985897CN', 'ZA678909461HK' -> $tracking-code {
    my %params = %(
        p_p_id => 'trackingPortlet_WAR_portalportlet',
        p_p_lifecycle => 2,
        # p_p_state => 'normal',
        # p_p_mode => 'view',
        p_p_resource_id => 'getList',
        # p_p_cacheability => 'cacheLevelPage',
        # p_p_col_id => 'column-1',
        # p_p_col_pos => 1,
        # p_p_col_count => 2,
        barcodeList => $tracking-code,
        # postmanAllowed => True,
        _ => 1564591754583,
    );
    my HTTP::UserAgent $ua .= new;
    my $resp = $ua.get('https://www.pochta.ru/tracking?' ~
    %params.map({"{.key}={.value}"}).join('&'));
    my %track = $resp.content.&from-json;

    say $tracking-code;
    %track<list>.head<trackingItem><trackingHistoryItemList>.map({
        my $d = do with .<date> {
            "{.yyyy-mm-dd} {.hh-mm-ss}" given DateTime.new($_)
        } // '?';
        "{$d}: {.<humanStatus>} @ {.<cityName> // '?'}"
    }).join("\n").say;
}
