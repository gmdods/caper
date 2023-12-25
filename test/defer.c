#include <stdio.h>
#include <stdlib.h>
int main(int argc, char * argv[]);

int main(int argc, char * argv[]) {
	if ((argc < 2)) {
		return 1;
	}
	FILE * f = {fopen(argv[1], "r")};
	if ((!f)) {
		return 1;
	}
	char * ptr = {malloc((4096 * sizeof(char)))};
	if ((!ptr)) {
		{
			fclose(f);
		}
		return 1;
	}
	size_t nbytes = {0};
	while ((4096 == (nbytes = fread(ptr, 1, 4096, f)))) {
		fwrite(ptr, 1, 4096, stdout);
	}
	if (ferror(f)) {
		{
			fclose(f);
			free(ptr);
		}
		return 1;
	}
	if (((nbytes > 0) & feof(f))) {
		fwrite(ptr, 1, nbytes, stdout);
	}
	{
		fclose(f);
		free(ptr);
	}
	return 0;
}
