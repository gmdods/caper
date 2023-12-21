#include <stdio.h>
#include <stdlib.h>
int main(int argc, char * argv[]) {
	if ((argc < 2)) {
		return 1;
	}
	FILE * f = {fopen(argv[1], "r")};
	char buffer[4096] = {0};
	size_t nbytes = {0};
	while ((4096 == (nbytes = fread(buffer, 1, 4096, f)))) {
		fwrite(buffer, 1, 4096, stdout);
	}
	if (ferror(f)) {
		return 1;
	}
	if (((nbytes > 0) & feof(f))) {
		fwrite(buffer, 1, nbytes, stdout);
	}
	fclose(f);
	return 0;
}
