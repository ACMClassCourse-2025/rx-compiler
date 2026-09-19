// REIMU provides these C functions directly to the simulated program.
unsafe extern "C" {
    fn printf(format: *const u8, ...) -> i32;
    fn scanf(format: *const u8, ...) -> i32;
}

#[allow(dead_code)]
pub fn print_i32(value: i32) {
    unsafe { printf(c"%d".as_ptr().cast(), value) };
}

#[allow(dead_code)]
pub fn println_i32(value: i32) {
    unsafe { printf(c"%d\n".as_ptr().cast(), value) };
}

#[allow(dead_code)]
pub fn get_i32() -> i32 {
    let mut value = 0;
    unsafe { scanf(c"%d".as_ptr().cast(), &mut value) };
    value
}
