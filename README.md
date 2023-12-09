# Caper
An attempt at a compile-time C.

## Literals

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
