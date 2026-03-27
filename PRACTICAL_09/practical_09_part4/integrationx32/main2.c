#include <stdio.h>

extern int subtract(int a, int b, int c);

int main(int argc, char **argv)
{
  printf("%d\n", subtract(4, 6, 8));
  return 0;
}
