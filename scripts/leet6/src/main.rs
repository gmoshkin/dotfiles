fn main() {
    println!("Hello, world!");
}

#[test]
fn test() {
    assert_eq!(solution("PAYPALISHIRING", 3), "PAHNAPLSIIGYIR");
}

fn solution<S>(s: S, n: usize) -> String
where
    S: Into<String> + std::borrow::Borrow<str>,
{
    if n == 1 { return s.into() }

    let s = s.borrow();

    let res = Vec::with_capacity(s.len());
    for i in 0..n {

    }
}

// PAYPALISHIRING
//
// P   A   H   N   PAHN APLSIIG YIR
// A P L S I I G
// Y   I   R

// 0   4   8   c   048c 13579bd 26a
// 1 3 5 7 9 b d
// 2   6   a

// P     I    N    PIN ALSIG YAHR PI
// A   L S  I G
// Y A   H R
// P     I

// 0     6     d   06d 157ce 248a 39
// 1   5 7   c e
// 2 4   8 a
// 3     9
