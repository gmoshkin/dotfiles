use std::any::Any;
use std::any::TypeId;

/// Returns an offset of the struct or tuple member in bytes.
///
/// Returns a constant which can be used at compile time.
///
/// # Example
/// ```rust
/// # use tarantool::offset_of;
/// #[repr(C)]
/// struct MyStruct { a: u8, b: u8 }
/// assert_eq!(offset_of!(MyStruct, a), 0);
/// assert_eq!(offset_of!(MyStruct, b), 1);
///
/// // Also works with tuples:
/// assert_eq!(offset_of!((i32, i32), 0), 0);
/// assert_eq!(offset_of!((i32, i32), 1), 4);
/// ```
#[macro_export]
macro_rules! offset_of {
    ($type:ty, $field:tt) => {{
        const RESULT: usize = unsafe {
            let dummy = ::core::mem::MaybeUninit::<$type>::uninit();
            let dummy_ptr = dummy.as_ptr();
            let field_ptr = ::std::ptr::addr_of!((*dummy_ptr).$field);

            let field_ptr = field_ptr.cast::<u8>();
            let dummy_ptr = dummy_ptr.cast::<u8>();
            field_ptr.offset_from(dummy_ptr) as usize
        };
        RESULT
    }};
}

#[derive(Debug)]
pub struct TypeInfo {
    /// In bytes.
    pub size: usize,
    /// In bytes.
    pub alignment: usize,
    pub name: &'static str,
    pub kind: TypeInfoKind,
}

impl TypeInfo {
    /// Returns type info of the nested type removing any sequence of references
    /// prepended to it. So for `&&&&T` it will return `T::TYPE_INFO`. But for
    /// any `T` which is not a reference it will return `T::TYPE_INFO` itself.
    pub const fn deref_all(&'static self) -> &'static Self {
        let mut iter = self;
        while let TypeInfoKind::Ref { to, .. } = iter.kind {
            iter = to;
        }
        iter
    }
}

#[derive(Debug)]
pub enum TypeInfoKind {
    Bool,
    Float,
    Integer {
        is_pointer_sized: bool,
        is_signed: bool,
    },
    Char,
    Str,
    Unit,
    Ref {
        is_mut: bool,
        to: &'static TypeInfo,
    },
    String {
        is_slice: bool,
    },
    Slice {
        of: &'static TypeInfo,
    },
    Array {
        count: usize,
        of: &'static TypeInfo,
    },
    Enum {
        variants: &'static [(&'static str, &'static TypeInfo)],
        names: &'static [&'static str],
        values: &'static [i64],
    },
    Struct {
        is_tuple: bool,
        fields_have_names: bool,
        fields: &'static [StructFieldInfo],
    }
}

#[derive(Debug)]
pub struct StructFieldInfo {
    /// This is empty, if field has no name.
    pub name: &'static str,
    pub offset: usize,
    pub type_info: &'static TypeInfo,
}

pub trait GetTypeInfo {
    const TYPE_INFO: &'static TypeInfo;
}

pub trait DynTypeInfo: Any {
    fn type_info(&self) -> &'static TypeInfo;

    #[inline(always)]
    fn type_name(&self) -> &'static str {
        std::any::type_name::<Self>()
    }
}

#[inline(always)]
pub fn downcast_ref<T>(any: &dyn DynTypeInfo) -> Option<&T>
where
    T: GetTypeInfo,
{
    if any.type_info() as *const _ != T::TYPE_INFO as *const _ {
        return None;
    }

    unsafe { Some(&*(any as *const dyn DynTypeInfo as *const T)) }
}

pub fn is_integer(any: &dyn Any) -> bool {
    let type_id = any.type_id();
    false
        || type_id == TypeId::of::<i8>()
        || type_id == TypeId::of::<i16>()
        || type_id == TypeId::of::<i32>()
        || type_id == TypeId::of::<i64>()
        || type_id == TypeId::of::<i128>()
        || type_id == TypeId::of::<isize>()
        || type_id == TypeId::of::<u8>()
        || type_id == TypeId::of::<u16>()
        || type_id == TypeId::of::<u32>()
        || type_id == TypeId::of::<u64>()
        || type_id == TypeId::of::<u128>()
        || type_id == TypeId::of::<usize>()
}

impl GetTypeInfo for () {
    const TYPE_INFO: &'static TypeInfo = &TypeInfo {
        size: std::mem::size_of::<()>(),
        alignment: std::mem::align_of::<()>(),
        name: "()",
        kind: TypeInfoKind::Unit,
    };
}

impl DynTypeInfo for () {
    fn type_info(&self) -> &'static TypeInfo {
        <Self as GetTypeInfo>::TYPE_INFO
    }
}

macro_rules! impl_get_type_info_for_integer {
    ($(($i:ty, is_pointer_sized: $is_pointer_sized:expr, is_signed: $is_signed:expr),)+) => {
        $(
            impl GetTypeInfo for $i {
                const TYPE_INFO: &'static TypeInfo = &TypeInfo {
                    size: std::mem::size_of::<Self>(),
                    alignment: std::mem::align_of::<Self>(),
                    name: stringify!($i),
                    kind: TypeInfoKind::Integer {
                        is_pointer_sized: $is_pointer_sized,
                        is_signed: $is_signed,
                    },
                };
            }

            impl DynTypeInfo for $i {
                fn type_info(&self) -> &'static TypeInfo {
                    <Self as GetTypeInfo>::TYPE_INFO
                }
            }
        )+
    }
}

impl GetTypeInfo for bool {
    const TYPE_INFO: &'static TypeInfo = &TypeInfo {
        size: std::mem::size_of::<Self>(),
        alignment: std::mem::align_of::<Self>(),
        name: "bool",
        kind: TypeInfoKind::Bool,
    };
}

impl DynTypeInfo for bool {
    fn type_info(&self) -> &'static TypeInfo {
        <Self as GetTypeInfo>::TYPE_INFO
    }
}

impl_get_type_info_for_integer! {
    (i8,    is_pointer_sized: false, is_signed: true),
    (i16,   is_pointer_sized: false, is_signed: true),
    (i32,   is_pointer_sized: false, is_signed: true),
    (i64,   is_pointer_sized: false, is_signed: true),
    (i128,  is_pointer_sized: false, is_signed: true),
    (isize, is_pointer_sized: true,  is_signed: true),
    (u8,    is_pointer_sized: false, is_signed: false),
    (u16,   is_pointer_sized: false, is_signed: false),
    (u32,   is_pointer_sized: false, is_signed: false),
    (u64,   is_pointer_sized: false, is_signed: false),
    (u128,  is_pointer_sized: false, is_signed: false),
    (usize, is_pointer_sized: true,  is_signed: false),
}

impl GetTypeInfo for f32 {
    const TYPE_INFO: &'static TypeInfo = &TypeInfo {
        size: std::mem::size_of::<Self>(),
        alignment: std::mem::align_of::<Self>(),
        name: "f32",
        kind: TypeInfoKind::Float,
    };
}

impl DynTypeInfo for f32 {
    fn type_info(&self) -> &'static TypeInfo {
        <Self as GetTypeInfo>::TYPE_INFO
    }
}

impl GetTypeInfo for f64 {
    const TYPE_INFO: &'static TypeInfo = &TypeInfo {
        size: std::mem::size_of::<Self>(),
        alignment: std::mem::align_of::<Self>(),
        name: "f64",
        kind: TypeInfoKind::Float,
    };
}

impl DynTypeInfo for f64 {
    fn type_info(&self) -> &'static TypeInfo {
        <Self as GetTypeInfo>::TYPE_INFO
    }
}

impl GetTypeInfo for char {
    const TYPE_INFO: &'static TypeInfo = &TypeInfo {
        size: std::mem::size_of::<Self>(),
        alignment: std::mem::align_of::<Self>(),
        name: "char",
        kind: TypeInfoKind::Char,
    };
}

impl DynTypeInfo for char {
    fn type_info(&self) -> &'static TypeInfo {
        <Self as GetTypeInfo>::TYPE_INFO
    }
}

impl GetTypeInfo for str {
    const TYPE_INFO: &'static TypeInfo = &TypeInfo {
        size: 0,
        alignment: 1,
        name: "str",
        kind: TypeInfoKind::Str,
    };
}

impl DynTypeInfo for str {
    fn type_info(&self) -> &'static TypeInfo {
        <Self as GetTypeInfo>::TYPE_INFO
    }
}

impl<T: GetTypeInfo> GetTypeInfo for [T] {
    const TYPE_INFO: &'static TypeInfo = &TypeInfo {
        size: 0,
        alignment: std::mem::align_of::<T>(),
        name: "[T]",
        kind: TypeInfoKind::Slice { of: T::TYPE_INFO },
    };
}

impl<T: 'static + GetTypeInfo> DynTypeInfo for [T] {
    fn type_info(&self) -> &'static TypeInfo {
        <Self as GetTypeInfo>::TYPE_INFO
    }
}

impl<T: GetTypeInfo, const N: usize> GetTypeInfo for [T; N] {
    const TYPE_INFO: &'static TypeInfo = &TypeInfo {
        size: std::mem::size_of::<Self>(),
        alignment: std::mem::align_of::<Self>(),
        name: "[T; N]",
        kind: TypeInfoKind::Array {
            count: N,
            of: T::TYPE_INFO,
        },
    };
}

impl<T: 'static + GetTypeInfo, const N: usize> DynTypeInfo for [T; N] {
    fn type_info(&self) -> &'static TypeInfo {
        <Self as GetTypeInfo>::TYPE_INFO
    }
}

impl<'a, T: 'a + GetTypeInfo + ?Sized> GetTypeInfo for &'a T {
    const TYPE_INFO: &'static TypeInfo = &TypeInfo {
        size: std::mem::size_of::<Self>(),
        alignment: std::mem::align_of::<Self>(),
        name: "&T",
        kind: TypeInfoKind::Ref {
            is_mut: false,
            to: T::TYPE_INFO,
        },
    };
}

impl<T> DynTypeInfo for &'static T
where
    T: 'static + ?Sized + GetTypeInfo,
{
    fn type_info(&self) -> &'static TypeInfo {
        <Self as GetTypeInfo>::TYPE_INFO
    }
}

const _: () = {
    assert!(<&str>::TYPE_INFO.size == 16);
};

impl<'a, T: 'a + GetTypeInfo + ?Sized> GetTypeInfo for &'a mut T {
    const TYPE_INFO: &'static TypeInfo = &TypeInfo {
        size: std::mem::size_of::<Self>(),
        alignment: std::mem::align_of::<Self>(),
        name: "&mut T",
        kind: TypeInfoKind::Ref {
            is_mut: true,
            to: T::TYPE_INFO,
        },
    };
}

impl<T: 'static + GetTypeInfo + ?Sized> DynTypeInfo for &'static mut T {
    fn type_info(&self) -> &'static TypeInfo {
        <Self as GetTypeInfo>::TYPE_INFO
    }
}

macro_rules! impl_get_type_info_for_tuple {
    () => {};
    ($H:ident $( $T:ident )*) => {
        impl<$H, $($T),*> GetTypeInfo for ($H, $($T),*)
        where
            $H: GetTypeInfo,
            $($T: GetTypeInfo,)*
        {
            const TYPE_INFO: &'static TypeInfo = &TypeInfo {
                size: std::mem::size_of::<Self>(),
                alignment: std::mem::align_of::<Self>(),
                name: stringify!(($H, $($T),*)),
                kind: TypeInfoKind::Struct {
                    is_tuple: true,
                    fields_have_names: false,
                    fields: &[
                        StructFieldInfo {
                            name: "",
                            offset: offset_of!(Self, 0),
                            type_info: $H::TYPE_INFO,
                        },
                        $(
                            StructFieldInfo {
                                name: "",
                                offset: panic!(), // theoretically this is possible to get, but it's retraded as shit
                                type_info: $T::TYPE_INFO,
                            },
                        )*
                    ],
                },
            };
        }

        impl_get_type_info_for_tuple! { $($T)* }
    };
}

impl_get_type_info_for_tuple! {
    T63 T62 T61 T60 T59 T58 T57 T56 T55 T54 T53 T52 T51 T50 T49 T48
    T47 T46 T45 T44 T43 T42 T41 T40 T39 T38 T37 T36 T35 T34 T33 T32
    T31 T30 T29 T28 T27 T26 T25 T24 T23 T22 T21 T20 T19 T18 T17 T16
    T15 T14 T13 T12 T11 T10  T9  T8  T7  T6  T5  T4  T3  T2  T1  T0
}

#[cfg(test)]
mod test {
    #[test]
    fn XXX() {
        dbg!(<([&mut &[(&str, i32)]; 10], (), (i32, i8, (f32,)))>::TYPE_INFO);
    }
}
