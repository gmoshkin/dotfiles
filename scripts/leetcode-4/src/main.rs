/*

lhs = [1, 3, 5, 7], rhs = [2, 4, 6, 8] |   m        M
       m                            M  | (0, 7)   (7, 0)
             m                M        | (4, 3)   (3, 4)
m <- l: 0
v <- lhs[m == l: 0] == 1
bin(rhs, v == 1) -> r: 0

m <- m + len(lhs) / 2 == l: 2
v <- lhs[m == l: 2] == 5
bin(rhs, v == 5) -> r: 2

found upper bound (4, 3)

M <- len(rhs) - 1 == r: 3
v <- rhs[M == r: 3] == 8
bin(lhs, v == 8) -> l: 3

M <- M - len(rhs) / 2 == r: 1
v <- rhs[M == r: 1] == 4
bin(lhs, v == 4) -> l: 2

found lower bound (3, 4)

R <- (lhs[m == l: 2] == 5 + rhs[M == r: 1] == 4) / 2 == 4.5

================================================================================

lhs = [1, 3, 5, 7, 9], rhs = [2, 4, 6, 8, 10] |   m        M
       m                                  M   | (0, 9)   (9, 0)
             m                      M         | (4, 5)   (5, 4)

[1,    3,    5,    7,    9    ]
[   2,    4,    6,    8,    10]

m <- l: 0
v <- lhs[m == l: 0] == 1
bin(rhs, v == 1) -> r: 0

m <- m + len(lhs) / 2 == l: 2
v <- lhs[m == l: 2] == 5
bin(rhs, v == 5) -> r: 2

found upper bound l: 2 (4, 5)

M <- len(rhs) - 1 == r: 4
v <- rhs[M == r: 4] == 10
bin(lhs, v == 10) -> l: 5

M <- M - len(rhs) / 2 == r: 2
v <- rhs[M == r: 2] == 6
bin(lhs, v == 6) -> l: 3

found lower bound r: 2 (5, 4)

R <- (lhs[m == l: 2] == 5 + rhs[M == r: 2] == 6) / 2 == 5.5

================================================================================

lhs = [1, 3], rhs = [2, 4, 5, 6, 7] |   m        M
       m                         M  | (0, 9)   (9, 0)

[   2,    4, 5, 6, 7]
[1,    3            ]

m <- l: 0
v <- lhs[m == l: 0] == 1
bin(rhs, v == 1) -> r: 0

m <- m + len(lhs) / 2 == l: 2
v <- lhs[m == l: 2] == 5
bin(rhs, v == 5) -> r: 2

found upper bound l: 2 (4, 5)

M <- len(rhs) - 1 == r: 4
v <- rhs[M == r: 4] == 10
bin(lhs, v == 10) -> l: 5

M <- M - len(rhs) / 2 == r: 2
v <- rhs[M == r: 2] == 6
bin(lhs, v == 6) -> l: 3

found lower bound r: 2 (5, 4)

R <- (lhs[m == l: 2] == 5 + rhs[M == r: 2] == 6) / 2 == 5.5

EZ
[  2   4 5 6 7]
[1   3        ]

EZ
[  2   4   6 7 8 9]
[1   3   5        ]

[  2   4   6   8 9]
[1   3   5   7    ]

[  2   4   6   8  ]
[1   3   5   7   9]

[          6 7    ]
[1 2 3 4 5     8 9]
   v               v
[  2   5   5   8   9]
[1   3   5   7   9  ]
 ^               ^

*/

macro_rules! red {
    ($m:literal) => {
        concat!["\x1b[31m", $m, "\x1b[0m"]
    };
}

pub fn find_median_sorted_arrays(nums1: Vec<i32>, nums2: Vec<i32>) -> f64 {
    if nums1.is_empty() { return median(&nums2) }
    if nums2.is_empty() { return median(&nums1) }

    let mut nums1 = nums1;
    let mut nums2 = nums2;

    if *nums2.last().unwrap() <= nums1[0] {
        std::mem::swap(&mut nums1, &mut nums2)
    }

    let len1 = nums1.len();
    let len2 = nums2.len();

    if nums1[len1 - 1] <= nums2[0] {
        match (len1 as i32) - (len2 as i32) {
            neg if neg < 0 => return median(&nums2[0..len2 - len1]),
            0              => return (nums1[len1 - 1] + nums2[0]) as f64 / 2.0,
            pos if pos > 0 => return median(&nums1[0..len1 - len2]),
            _ => unreachable!("Everything covered"),
        }
    }

    let overall_len = len1 + len2;

    let mut pos1 = 0;
    let mut pos2 = 0;
    let mut ofs1 = len1 / 2;
    let mut ofs2 = len2 / 2;
    loop {
        let last_val_pos1 = pos1;
        let last_val_pos2 = pos2;

        let pos1in2 = bin(&nums2, nums1[pos1]);
        let pos2in1 = bin(&nums1, nums2[pos2]);

        let overall_pos1 = pos1 + pos1in2;
        let overall_pos2 = pos2 + pos2in1;
        if overall_len % 2 != 0 {
            if overall_pos1 == overall_len / 2 { return nums1[pos1] as f64; }
            if overall_pos2 == overall_len / 2 { return nums2[pos2] as f64; }
        } else {

        }

        macro_rules! move_pos {
            ($overall_pos:ident, $pos:ident, $ofs:ident, $len:ident) => {
                if $overall_pos < overall_len / 2 {
                    if $pos + $ofs < $len {
                        $pos += $ofs;
                    }
                } else if $pos > $ofs {
                    $pos -= $ofs;
                }
                $ofs /= 2;
            }
        }

        move_pos!(overall_pos1, pos1, ofs1, len1);
        move_pos!(overall_pos2, pos2, ofs2, len2);

        if pos1 == last_val_pos1 && pos2 == last_val_pos2 {
            dbg!((nums1, pos1, nums2, pos2));
            panic!(red!("Endless loop"))
        }
    }
}

#[test]
fn find_median_sorted_arrays_test() {
    macro_rules! fmsa {
        ([$($l:expr),* $(,)?] + [$($r:expr),* $(,)?] -> $m:expr) => {
            assert_eq!(
                find_median_sorted_arrays(vec![$( $l ),*], vec![$( $r ),*]),
                $m as f64,
            );
        }
    }
    fmsa!([] + [1] -> 1);
    fmsa!([2] + [] -> 2);
    fmsa!([1] + [2] -> 1.5);
    fmsa!([3] + [1] -> 2);
    fmsa!([3, 4, 5, 6] + [1] -> 4);
    fmsa!([3, 4, 5] + [1, 2, 3] -> 3);
    fmsa!([1, 3, 5] + [2, 4, 6, 7] -> 4);
    fmsa!([1, 3, 5, 7] + [2, 4, 6] -> 4);
    fmsa!([1, 3, 5, 7] + [4] -> 4);
    fmsa!([1, 2, 3, 4, 5,       8, 9]
        + [               6, 7,     ] -> 5);
    fmsa!([               6, 7,     ]
        + [1, 2, 3, 4, 5,       8, 9] -> 5);

    fmsa!([1,    3,    5,  ]
        + [   2,    4,    6] -> 3.5);
    fmsa!([1,    3, 4,     ]
        + [   2,       5, 6] -> 3.5);
}

pub fn find_median_sorted_arrays_2(nums1: Vec<i32>, nums2: Vec<i32>) -> f64 {
    if nums1.len() + nums2.len() == 2 {
        if nums1.is_empty() {
            return (nums2[0] + nums2[1]) as f64 / 2.0
        } else if nums2.is_empty() {
            return (nums1[0] + nums1[1]) as f64 / 2.0
        } else {
            (nums1[0] + nums2[0]) as f64 / 2.0
        }
    }
    if nums1.is_empty() { return median(&nums2) }
    if nums2.is_empty() { return median(&nums1) }

    let mut nums1 = nums1;
    let mut nums2 = nums2;

    if *nums2.last().unwrap() <= nums1[0] {
        std::mem::swap(&mut nums1, &mut nums2)
    }

    let len1 = nums1.len();
    let len2 = nums2.len();

    if nums1[len1 - 1] <= nums2[0] {
        match (len1 as i32) - (len2 as i32) {
            neg if neg < 0 => return median(&nums2[0..len2 - len1]),
            0              => return (nums1[len1 - 1] + nums2[0]) as f64 / 2.0,
            pos if pos > 0 => return median(&nums1[0..len1 - len2]),
            _ => unreachable!("Everything covered"),
        }
    }

    let overall_len = len1 + len2;

    let mut pos1 = 0;
    let mut pos2 = 0;
    let mut ofs1 = len1 / 2;
    let mut ofs2 = len2 / 2;
    loop {
        let last_val_pos1 = pos1;
        let last_val_pos2 = pos2;

        let pos1in2 = bin(&nums2, nums1[pos1]);
        let pos2in1 = bin(&nums1, nums2[pos2]);

        let overall_pos1 = pos1 + pos1in2;
        let overall_pos2 = pos2 + pos2in1;
        if overall_len % 2 != 0 {
            if overall_pos1 == overall_len / 2 { return nums1[pos1] as f64; }
            if overall_pos2 == overall_len / 2 { return nums2[pos2] as f64; }
        } else {

        }

        macro_rules! move_pos {
            ($overall_pos:ident, $pos:ident, $ofs:ident, $len:ident) => {
                if $overall_pos < overall_len / 2 {
                    if $pos + $ofs < $len {
                        $pos += $ofs;
                    }
                } else if $pos > $ofs {
                    $pos -= $ofs;
                }
                $ofs /= 2;
            }
        }

        move_pos!(overall_pos1, pos1, ofs1, len1);
        move_pos!(overall_pos2, pos2, ofs2, len2);

        if pos1 == last_val_pos1 && pos2 == last_val_pos2 {
            dbg!((nums1, pos1, nums2, pos2));
            panic!(red!("Endless loop"))
        }
    }
}
fn median(slice: &[i32]) -> f64 {
    let mid = slice.len() / 2;
    if slice.len() % 2 == 0 {
        (slice[mid - 1] + slice[mid]) as f64 / 2.0
    } else {
        slice[mid] as f64
    }
}

fn bin(slice: &[i32], v: i32) -> usize {
    if slice.is_empty() {
        0
    } else if slice.len() == 1 {
        (slice[0] < v) as usize
    } else {
        let mid = slice.len() / 2;
        if slice[mid] < v {
            mid + bin(&slice[mid..], v)
        } else {
            bin(&slice[..mid], v)
        }
    }
}

#[test]
fn bin_test() {
    assert_eq!(bin(&[1, 2, 3], 2), 1);
    assert_eq!(bin(&[2, 2, 2], 2), 0);
    assert_eq!(bin(&[1, 3, 5, 7, 9], 6), 3);
    assert_eq!(bin(&[1, 3, 5, 7, 9], -1), 0);
}

#[test]
fn median_test() {
    assert_eq!(median(&[1, 2, 3]), 2.0);
    assert_eq!(median(&[2, 2, 2]), 2.0);
    assert_eq!(median(&[1, 3, 5, 7, 9]), 5.0);
    assert_eq!(median(&[1, 3, 5, 7, 9, 11]), 6.0);
}

macro_rules! check {
    ([$($l:expr),* $(,)?] + [$($r:expr),* $(,)?] -> $m:expr) => {
        {
            let lhs = vec![$( $l ),*];
            let rhs = vec![$( $r ),*];
            print!("{:?} + {:?}", lhs, rhs);
            let m = find_median_sorted_arrays(lhs, rhs);
            print!(" -> {}", m);
            if m != ($m as f64) { println!(" !{}", $m) } else { println!("") }
        }
    };
}

fn main() {
    check!([] + [1] -> 1);
    check!([2] + [] -> 2);
    check!([1] + [2] -> 1.5);
    check!([3] + [1] -> 2);
    check!([3, 4, 5, 6] + [1] -> 4);
    check!([3, 4, 5] + [1, 2, 3] -> 3);
    check!([1, 3, 5] + [2, 4, 6, 7] -> 4);
    check!([1, 3, 5, 7] + [2, 4, 6] -> 4);
    check!([1, 3, 5, 7] + [4] -> 4);
    check!([1, 3, 5] + [2, 4, 6] -> 4.5);
}
