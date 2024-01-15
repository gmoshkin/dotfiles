////////////////////////////////////////////////////////////////////////////////
// random_u64
////////////////////////////////////////////////////////////////////////////////

/// Returns a pseudo-random `u64` value.
///
/// Implemented as a simple [LCG] based on [this article].
///
/// [LCG]: https://en.wikipedia.org/wiki/Linear_congruential_generator
/// [this article]: https://www.pcg-random.org/posts/does-it-beat-the-minimal-standard.html
pub fn random_u64() -> u64 {
    const FACTOR: u128 = 0x2d99787926d46932a4c1f32680f70c55;

    thread_local! {
        static STATE: Cell<Option<u128>> = Cell::new(None);
    }

    let res = STATE.with(|state_cell| {
        if state_cell.get().is_none() {
            state_cell.set(Some(get_rng_seed()))
        }
        let mut state = state_cell.get().unwrap();
        state = state.wrapping_mul(FACTOR);
        state = state.wrapping_add(FACTOR);
        state_cell.set(Some(state));
        return (state >> 64) as u64;
    });

    return res;
}

/// Returns a pseudo-random element from `data`.
/// Returns `None` if `data` is empty.
///
/// See [`random_u64`] for details about pseudo-random number generator being used.
#[inline]
pub fn random_choice<T>(data: &[T]) -> Option<&T> {
    if data.is_empty() {
        return None;
    }
    let i = (random_u64() as usize) % data.len();
    Some(&data[i])
}

/// Currently returns the system time in nanoseconds.
fn get_rng_seed() -> u128 {
    let mut timespec = std::mem::MaybeUninit::uninit();
    // SAFETY: this is safe because types are being checked and all values are valid
    let rc = unsafe { libc::clock_gettime(libc::CLOCK_REALTIME, timespec.as_mut_ptr()) };
    if rc != 0 {
        let err = std::io::Error::last_os_error();
        eprintln!("failed to get time: {}", err);
        if cfg!(debug_assertions) {
            panic!("failed to get time: {}", err);
        }
        return 0;
    }
    // SAFETY: safe because rc != 0, therefore the value was initialized
    let timespec = unsafe { timespec.assume_init() };

    const NANOS_PER_SECOND: u128 = 1_000_000_000;

    let mut seed = timespec.tv_nsec as u128;
    seed += (timespec.tv_sec as u128) * NANOS_PER_SECOND;
    return seed;
}