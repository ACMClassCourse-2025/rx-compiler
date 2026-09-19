// Bare-metal entry point for the bundled rustc reference compiler.
#![no_std]
#![cfg_attr(not(rx_semantic), no_main)]

extern crate alloc;

use alloc::{boxed::Box, vec::Vec};
use core::alloc::{GlobalAlloc, Layout};

include!(env!("RX_SOURCE"));

#[cfg(not(rx_semantic))]
#[export_name = "main"]
extern "C" fn reference_main() -> i32 {
    let _: () = main();
    0
}

struct ReimuAllocator;

unsafe extern "C" {
    fn malloc(size: usize) -> *mut u8;
    fn free(pointer: *mut u8);
}

unsafe impl GlobalAlloc for ReimuAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        // REIMU's malloc guarantees 16-byte alignment.
        if layout.align() > 16 {
            return core::ptr::null_mut();
        }
        unsafe { malloc(layout.size()) }
    }

    unsafe fn dealloc(&self, pointer: *mut u8, _layout: Layout) {
        unsafe { free(pointer) };
    }
}

#[global_allocator]
static ALLOCATOR: ReimuAllocator = ReimuAllocator;

#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    // Jump outside executable memory so REIMU reports a runtime failure.
    loop {
        // Keep a Rust loop here: noreturn asm makes LLVM append an `unimp`
        // instruction, which REIMU cannot assemble even on an untaken path.
        unsafe { core::arch::asm!("jr zero") };
    }
}
