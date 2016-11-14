/*
 Print the symbol predefined by linker
 */

extern int end, etext, edata;
extern int _end, _etext, _edata;

int main(void)
{
	printf("&etext = %p, &edata = %p, &end = %p\n", \
			&etext, &edata, &end);
	printf("&_etext = %p, &_edata = %p, &_end = %p\n", \
			&_etext, &_edata, &_end);
	return 0;	
}
