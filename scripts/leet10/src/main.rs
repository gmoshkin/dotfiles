fn main() {
    println!("Hello, world!");
}

#[test]
fn test() {
    assert!(solution("aab", "c*a*b*"));
}

fn solution(
    s: impl std::borrow::Borrow<str>, p: impl std::borrow::Borrow<str>
) -> bool {
    let s_chars = s.borrow().chars();
    let mut p_chars = p.borrow().chars().peekable();
    let mut next_part = || {
        if let Some(c) = p_chars.next() {
            if let Some('*') = p_chars.peek() {
                if c == '.' {
                    Some(RePart::RepeatDot)
                } else {
                    Some(RePart::Repeat(c))
                }
            } else if c == '.' {
                Some(RePart::Dot)
            } else {
                Some(RePart::Single(c))
            }
        } else {
            None
        }
    };

    for c in s_chars {
        let np = next_part();
        if np.is_none() { return false }
        match np.unwrap() {
            RePart::Single(ec) => {
                if c != ec {
                    return false
                }
            }
            RePart::Dot => {},
        }
    }

    enum RePart {
        Single(char),
        Repeat(char),
        Dot,
        RepeatDot,
    }
    unimplemented!()
}
