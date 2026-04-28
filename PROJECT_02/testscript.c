#include <stdio.h>
#include <assert.h>
#include <limits.h>
 
extern long register_adder(long a, long b);
 
int main(void)
{
    assert(register_adder(3, 5)   == 8);
    assert(register_adder(10, 20) == 30);
    assert(register_adder(30, 10) == 40);
    assert(register_adder(1110, 1) == 1111);
    assert(register_adder(0, 0)   == 0);
    printf("Tests passed!\n");
    return 0;
}