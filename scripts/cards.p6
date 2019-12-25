#!/usr/bin/env perl6

enum Suit <Hearts Spades Diamonds Clubs>;
enum CardVal (%{
    'Ace'   => 1,
    (2..9).map({.Str.uniname.words.tail.tc => .Int}),
    'Ten'   => 10,
    'Jack'  => 11,
    'Queen' => 12,
    'King'  => 13,
});

subset RedSuit of Suit where Hearts | Diamonds;
multi sub color(RedSuit) { 31 }
subset BlackSuit of Suit where Spades | Clubs;
multi sub color(BlackSuit) { 34 }

class Card {
    has Suit $.suit;
    has CardVal $.val;

    multi method new(CardVal() $val, Suit() $suit) {
        self.bless(:$val, :$suit);
    }

    method Str {
        uniparse("playing card {$.val} of {$.suit}")
            .fmt("\e[{$.suit.&color}m%s\e[0m")
    }
};

multi sub infix:<of> (CardVal() $val, Suit() $suit) {
    Card.new(:$val, :$suit)
}
# say Ace of Spades

my @deck = ((CardVal::.values) Xof (Suit::.values)).pick: *;
say @deck.fmt;

# TODO
# Klondike => ['Column' xx 7, 'Deck', 'Foundation Pile' xx 4, 'Draw Pile']
