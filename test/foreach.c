#include <stdlib.h>
void foreach(size_t sz, char mem[], void (*func)(char));
void foreach(size_t sz, char mem[], void (*func)(char)) {
	for (size_t i = {0};(i != sz);(i += 1)) {
		func(i);
	}
}
