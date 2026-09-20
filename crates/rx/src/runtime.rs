// Bare-metal runtime supplied by REIMU.
use ::core::alloc::{GlobalAlloc, Layout};

struct ReimuAllocator;

unsafe extern "C" {
    fn malloc(size: usize) -> *mut u8;
    fn free(pointer: *mut u8);
}

unsafe impl GlobalAlloc for ReimuAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        // REIMU's malloc guarantees 16-byte alignment.
        if layout.align() > 16 {
            return ::core::ptr::null_mut();
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
fn panic(_info: &::core::panic::PanicInfo) -> ! {
    // Jump outside executable memory so REIMU reports a runtime failure.
    loop {
        // Keep a Rust loop here: noreturn asm makes LLVM append an `unimp`
        // instruction, which REIMU cannot assemble even on an untaken path.
        unsafe { ::core::arch::asm!("jr zero") };
    }
}
