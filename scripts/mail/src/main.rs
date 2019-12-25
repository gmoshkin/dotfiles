use reqwest;

// pub fn main() {
//     match reqwest::get("https://wttr.in/Moscow?format=3") {
//         Ok(mut resp) => match resp.text() {
//             Ok(body) => print!("{}", body),
//             Err(e) => print!("Can't get response text! {}", e),
//         },
//         Err(e) => print!("Can't execute the request! {}", e),
//     }
// }

pub fn main() -> Result<(), reqwest::Error> {
    Ok(print!("{}", reqwest::get("https://wttr.in/Moscow?format=3")?.text()?))
}

// pub fn main() -> Result<(), reqwest::Error> {
//     reqwest::get("https://wttr.in/Moscow?format=3")
//         .and_then(|mut resp| resp.text().map(|body| print!("{}", body)))
// }

// pub fn main() {
//     if let Ok(mut resp) = reqwest::get("https://wttr.in/Moscow?format=3") {
//         if let Ok(body) = resp.text() {
//             print!("{}", body)
//         }
//     }
// }
