#include <stdio.h>
int main(int argc, char * argv[]);
int main(int argc, char * argv[]) {
	if ((argc < 2)) {
		return 1;
	}
	puts(argv[1]);
	return 0;
}
