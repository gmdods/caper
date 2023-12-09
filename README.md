# Caper
An attempt at a compile-time C.

## Building

The bootstrap implementation is in Julia.
_In future_:
There will be a Caper to C translator and a self-hosted compiler.
The generated C translation of the compiler could build Caper in any system (with libc).

## Language Syntax

### Literals

Standard decimal With Lispy (also Julia and Elixir) compile-time
readers and [sigils](https://en.wikipedia.org/wiki/Sigil_(computer_programming)#Literal_affixes).

```elixir
1, -2 # Nat, Int
b'10110', h'ffff' # Bits
f'1.0', f'-Inf', f'1e3' # Floats
char'a', utf'é' # ASCII, UTF codepoint
re'\p{L}[\p{L}\p{N}]*\s+=\s+\p{N}+' # Regex
fmt'%s = %u;' # Format
```
