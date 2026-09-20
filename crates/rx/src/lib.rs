#![no_std]

pub mod core;

#[cfg(all(target_arch = "riscv32", target_os = "none"))]
mod runtime;
