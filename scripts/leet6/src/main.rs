fn main() {
    println!("{}", solution("ABCDEFGHIJKL", 5));
    // A   E   I
    // B D F H J L
    // C   G   K

    // A     G
    // B   F H   L
    // C E   I K
    // D     J

    // A       I
    // B     H J
    // C   G   K
    // D F     L
    // E
}

#[test]
fn test() {
    assert_eq!(solution("PAYPALISHIRING", 3), "PAHNAPLSIIGYIR")
}

fn solution<S>(s: S, num_rows: i32) -> String
where
    S: Into<String>,
{
    let s = s.into();
    let n = num_rows as usize;

    if n == 1 {
        return s
    }

    let mut res = vec![];

    let b = s.into_bytes();

    for i in (0..b.len()).step_by(2 * n - 2) {
        res.push(b[i])
    }

    for j in 1..(n - 1) {
        for i in (j..b.len()).step_by(2 * n - 2) {
            res.push(b[i]);
            let k = i + (2 * n - 2) - 2 * j;
            if k < b.len() {
                res.push(b[k])
            }
        }
    }

    for i in ((n - 1)..b.len()).step_by(2 * n - 2) {
        res.push(b[i])
    }

    String::from_utf8(res).unwrap()
}
