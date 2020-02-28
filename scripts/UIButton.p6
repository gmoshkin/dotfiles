#!/usr/bin/env perl6

class UIButton {
    method setTitle($title, :$for) {
        #
    }
}

enum HZ <gift giveTrash getTrash>;

my $input = HZ::.values.pick;

dd $input;

my $table-footer-view =
    $input eqv gift
        ??
    Nil
        !!
    UIButton.new.&{
        .setTitle(:{
            (giveTrash) => "бросить в корзину",
            (getTrash)  => "забрать мусор",
        }{$input},
        for => <normal>);
        $_
    };

dd $table-footer-view;
