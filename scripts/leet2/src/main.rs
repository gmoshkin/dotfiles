macro_rules! list {
    ($(,)?) => { None };
    ($head:expr $(, $tail:expr )* $(,)?) => {
        Some(Box::new(ListNode { val: $head, next: list!($($tail),*)}))
    };
}

fn main() {
    println!("{:?}", list![1, 2, 3]);
}

#[test]
fn test() {
    assert_eq!(solution(list![1], list![2]), list![3]);
    assert_eq!(solution(list![2, 4, 3], list![5, 6, 4]), list![7, 0, 8]);
    assert_eq!(solution(list![9, 9, 9, 9, 9, 9, 9], list![9, 9, 9, 9]), list![8, 9, 9, 9, 0, 0, 0, 1]);
}

#[derive(PartialEq, Eq, Clone, Debug)]
struct ListNode {
    val: i32,
    next: Option<Box<ListNode>>,
}

fn solution(
    l1: Option<Box<ListNode>>, l2: Option<Box<ListNode>>
) -> Option<Box<ListNode>> {
    return solution_impl(to_ref(&l1), to_ref(&l2), false);

    fn solution_impl(
        l1: Option<&ListNode>, l2: Option<&ListNode>, carry: bool
    ) -> Option<Box<ListNode>> {
        if l1.is_none() && l2.is_none() {
            return
                if carry {
                    Some(Box::new(ListNode { val: 1, next: None }))
                } else {
                    None
                }
        }

        let val = l1.map(|l| l.val).unwrap_or(0)
                + l2.map(|l| l.val).unwrap_or(0)
                + carry as i32;

        let carry = val > 9;
        let val = if carry { val - 10 } else { val };
        Some(
            Box::new(
                ListNode {
                    val,
                    next: solution_impl(next_ref(l1), next_ref(l2), carry),
                }
            )
        )
    }

    fn to_ref(l: &Option<Box<ListNode>>) -> Option<&ListNode> {
        l.as_ref().map(AsRef::as_ref)
    }

    fn next_ref(l: Option<&ListNode>) -> Option<&ListNode> {
        l.and_then(|l| to_ref(&l.next))
    }
}

trait ListNodeExt {
    fn to_ref(this: &Option<Box<Self>>) -> Option<&Self>;
    fn next_ref(this: Option<&Self>) -> Option<&Self>;
}

impl ListNodeExt for ListNode {
    fn to_ref(this: &Option<Box<Self>>) -> Option<&Self> {
        this.as_ref().map(AsRef::as_ref)
    }

    fn next_ref(this: Option<&Self>) -> Option<&Self> {
        this.and_then(|l| ListNode::to_ref(&l.next))
    }
}