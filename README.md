# Caper
An attempt at an extended C.

## Building

The bootstrap implementation is in Julia.
_In future_:
There will be a Caper to C translator and a self-hosted compiler.
The generated C translation of the compiler could build Caper in any system (with libc).

## Language Syntax

For now, we only describe the differences with C.

### Literals

Standard decimal With Lispy (also Julia and Elixir) compile-time
readers and [sigils](https://en.wikipedia.org/wiki/Sigil_(computer_programming)#Literal_affixes).

Sigils are case-insensitive.

```elixir
1, -2 # Nat, Int
b'10110', h'ffff' # Bits
f'1.0', f'-Inf', f'1e3' # Floats
char'a', utf'é' # ASCII, UTF codepoint
Re'\p{L}[\p{L}\p{N}]*\s+=\s+\p{N}+' # Regex
Fmt"%s = %u;" # Format
D"2000-01-01", T"12:00:01" # Date Time
```

## Declarations

Variable declarations are similar to C++ uniform initialization, however,
similar to Rust, Zig, Odin, Jai, etc., uses "<var> : <type>" instead of "<type> <var>".

```c
delta: int{0};
ptr: int^{nil};
array: int[3]{0, 1, 2};
func: int(int, int)^{add};
mask: _{h"ff"}; // auto
```

## Functions

```c
memcpy: fn (src: byte_t[_], dst: byte_t[_], nbytes: size_t): void {
    for (; nbytes > 0; nbytes -= 1) {
        dst[nbytes] = src[nbytes];
    }
};
```
