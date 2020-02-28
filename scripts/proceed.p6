#!/usr/bin/env perl6

given 13 {
    when *.is-prime               { say "$?LINE prime"; proceed }
    when &is-prime                { say "$?LINE prime"; proceed }
    when .is-prime                { say "$?LINE prime"; proceed }
    when { .is-prime }            { say "$?LINE prime"; proceed }
    when { $_.is-prime }          { say "$?LINE prime"; proceed }
    when { $^n.is-prime }         { say "$?LINE prime"; proceed }
    when -> $_ { .is-prime }      { say "$?LINE prime"; proceed }
    when -> $n { $n.is-prime }    { say "$?LINE prime"; proceed }
    when -> \n { n.is-prime }     { say "$?LINE prime"; proceed }
    when sub ($n) { $n.is-prime } { say "$?LINE prime"; proceed }
}
