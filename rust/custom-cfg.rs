// compile with `rustc --cfg 'poopoo="kaka"' %`
fn main() {
    println!("hi: {}", cfg!(poopoo = "kaka"));
}
