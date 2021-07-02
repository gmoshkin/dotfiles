fn main() {
    println!("Hello, world!");
}

#[test]
fn test() {
    assert_eq!(solution("   -42 with words"), -42);
    assert_eq!(solution("-2147483648"), -2147483648);
    assert_eq!(solution("2147483648"), 2147483647);
    assert_eq!(solution("-2147483649"), -2147483648);
    assert_eq!(solution("2147483647"), 2147483647);
}

fn solution(s: impl std::borrow::Borrow<str>) -> i32 {
    let mut chars = s.borrow().chars().peekable();
    loop {
        if chars.peek().is_none() {
            return 0
        }
        if !chars.peek().unwrap().is_whitespace() {
            break
        }
        chars.next();
    }

    let mut is_negative = false;
    match chars.peek().unwrap() {
        '-' => { is_negative = true; chars.next(); }
        '+' => { is_negative = false; chars.next(); }
        _ => (),
    }

    let mut res = 0isize;

    macro_rules! signed {
        () => {
            if is_negative { -res } else { res }
        };
    }

    loop {
        if chars.peek().is_none() || !chars.peek().unwrap().is_digit(10) {
            break
        }
        let d = chars.next().unwrap() as isize - '0' as isize;
        res = res * 10 + d;

        if signed!() < std::i32::MIN as isize {
            return std::i32::MIN
        } else if signed!() > std::i32::MAX as isize {
            return std::i32::MAX
        }
    }

    if is_negative {
        res = -res
    }

    res as i32
}
