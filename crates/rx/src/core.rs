use text_io::read;

#[allow(dead_code)]
pub fn print_i32(value: i32) {
    print!("{}", value);
}

#[allow(dead_code)]
pub fn println_i32(value: i32) {
    println!("{}", value);
}

#[allow(dead_code)]
pub fn get_i32() -> i32 {
    read!()
}
