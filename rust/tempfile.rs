/// Creates a temporary file in the directory returned by [`std::env::temp_dir`].
/// Returns a path to this file.
///
/// # Panicking
/// Panics if file couldn't be created due to a system error.
/// Panics if it can't find an available random name in an alotted number of
/// attempts.
pub fn create_random_file() -> std::path::PathBuf {
    const POSTFIX_CHARACTERS: &[u8] = b"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    const NUN_ATTEMPTS: usize = 10;

    for _ in 0..NUN_ATTEMPTS {
        let mut buf = [b'0'; 10];
        for b in &mut buf {
            let c = crate::util::random_choice(POSTFIX_CHARACTERS);
            *b = *c.unwrap();
        }
        let postfix = std::str::from_utf8(&buf).expect("only contains ASCII");

        let mut path = std::env::temp_dir();
        path.push(format!("tmp-{postfix}"));
        let res = std::fs::File::create(&path);
        match res {
            Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => {
                // Retry
                continue;
            },
            Err(e) => {
                panic!("failed to create a temporary file '{:?}': {}", path, e);
            }
            Ok(_) => {
                // close the file
            }
        }
        return path;
    }

    panic!("failed to create a temporary file: too many retries");
}
