// Per-test crate root and bare-metal entry point for REIMU.
#![no_std]
#![cfg_attr(not(rx_semantic), no_main)]

extern crate alloc;
extern crate rx;

use alloc::{boxed::Box, vec::Vec};

include!(env!("RX_SOURCE"));

#[cfg(not(rx_semantic))]
#[export_name = "main"]
extern "C" fn reference_main() -> i32 {
    let _: () = main();
    0
}
