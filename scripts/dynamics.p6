#!/usr/bin/env perl6

class Attributed {
    has SetHash $.attributes;
    has $.text;

    method new(:$text, :@attributes) {
        self.bless(:$text, :attributes(SetHash.new(@attributes)))
    }

    method set-attr($attr) {
        $.attributes{$attr} = True;
        self
    }
}

class Paragraph {
    has @.fragments;
}

class Document {
    has @.paragraphs;
}

sub document(&cb) {
    my $*document = Document.new(:paragraphs[]);
    cb;
    $*document
}

sub paragraph(&cb) {
    my $*paragraph = Paragraph.new(:frags[]);
    cb;
    $*document.paragraphs.append($*paragraph).tail
}

sub attributed($text, *@attributes) {
    $*paragraph.fragments.append(Attributed.new(:$text, :@attributes)).tail
}

multi text($text)                { attributed($text) }
multi text(Attributed:D $text)   { $text }
multi bold($text)                { attributed($text, &?ROUTINE.name) }
multi bold(Attributed:D $text)   { $text.set-attr(&?ROUTINE.name) }
multi italic($text)              { attributed($text, &?ROUTINE.name) }
multi italic(Attributed:D $text) { $text.set-attr(&?ROUTINE.name) }

dd
document {
    paragraph {
        bold italic bold 'fuck'
    }
    paragraph {
        bold 'shit'
    }
    paragraph {
        text 'ass'
    }
}

