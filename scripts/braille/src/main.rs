fn main() -> Result<(), String> {
    let Some(arg) = std::env::args().skip(1).next() else {
        return Err("give me 8 bits".into());
    };
    if arg.len() != 8 {
        return Err(format!("expected 8 bits, got '{arg}' (len: {})", arg.len()));
    }

    let mut res = 0x2800;
    for (c, i) in arg.chars().zip([0x1, 0x8, 0x2, 0x10, 0x4, 0x20, 0x40, 0x80]) {
        if c == '1' {
            res += i;
        }
    }
    println!("{}", std::char::from_u32(res).unwrap());

    Ok(())
}
