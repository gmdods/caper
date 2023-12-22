#include <stdlib.h>
char memory[32] = {0};
size_t find(size_t sz, char mem[], char c);
size_t loop(size_t sz, char mem[], char c, size_t ext);

size_t loop(size_t sz, char mem[], char c, size_t ext) {
	if ((ext >= sz)) {
		return sz;
	}
	if ((mem[ext] == c)) {
		return ext;
	}
	return loop(sz, mem, c, (ext + 1));
}

size_t find(size_t sz, char mem[], char c) {
	extern size_t loop(size_t sz, char mem[], char c, size_t ext);
	return loop(sz, mem, c, 0);
}
