extern crate http;
use http::Request;

pub fn main() {
    let mut request = Request::builder();
    request.uri("https://wttr.in/Moscow?format=3");

    let response = send(request.body(()).unwrap());

    print!("{}", response.body(()));
}
