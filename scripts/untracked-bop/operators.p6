multi sub postfix:<!>(Numeric:D \n) { [*] 1..n }
say 1!;
say 10!;
multi sub postfix:<%>(Numeric:D \n) { n / 100 }
say 1%;
say 100%;
multi sub postfix:<‰>(Numeric:D \n) { n / 1000 }
say 1‰;
say 100‰;
say 1000‰;
multi sub prefix:<☹>(Any:D \x) { "sad {x}" }
say ☹ 1;
say ☹ 'sad';

multi sub circumfix:<J{ }> (*@pairs where .all ~~ Pair:D) { @pairs.Hash }
try say J{ 1 };
say $!;

multi sub infix:<:> (Any:D $lhs is raw, Any:D $rhs is raw) is equiv(&[=>])  { $lhs => $rhs }
say (1 : 2);
# (1 : 2).say;
# Confused
# at /home/gmoshkin/dotfiles/scripts/operators.p6:21
# ------> (1 :⏏ 2).say;
#     expecting any of:
#         colon pair
say (1 : 2), 1 => 2;
say J{"int" : 2};

my $p = (1 : 2);
say $p;

multi sub infix:<::> (Any:D $lhs is raw, Any:D $rhs is raw) is equiv(&[=>])  { $lhs => $rhs }
say 1 :: 2;
(1 :: 2).say;
say 1 :: 2, 3 :: 4;
say {1 :: 2, 3 :: 4};
say J{1 :: 2, 3 :: 4};
say J{"int" :: 2, "arr" :: [3, 4], "dict" :: J{ "str" :: "ass" }};
say %(:2int, arr => [3, 4], :dict({ :str<ass> }));

# say {(1 : 2), (2 : 3)};
# Confused
# at /tmp/test.p6:40
# ------> say {(1 : 2), (2 :⏏ 3)};
#     expecting any of:
#         colon pair
