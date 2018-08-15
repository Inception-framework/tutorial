#include<stdlib.h>
#ifdef KLEE
#include <assert.h>
#include <stdio.h>
#endif

__attribute__((naked))
int fibonacci_asm(int n){
  __asm volatile("push	{r4, r7, lr}");
  __asm volatile("sub	sp, #12");
  __asm volatile("add	r7, sp, #0");
  __asm volatile("str	r0, [r7, #4]");
  __asm volatile("ldr	r3, [r7, #4]");
  __asm volatile("cmp	r3, #3");
  __asm volatile("bhs	continue");
  __asm volatile("movs	r3, #1");
  __asm volatile("b.n	stop");
  __asm volatile("continue:");
  __asm volatile("ldr	r3, [r7, #4]");
  __asm volatile("subs	r3, #1");
  __asm volatile("mov	r0, r3");
  __asm volatile("bl	fibonacci_asm");
  __asm volatile("mov	r4, r0");
  __asm volatile("ldr	r3, [r7, #4]");
  __asm volatile("subs	r3, #2");
  __asm volatile("mov	r0, r3");
  __asm volatile("bl	fibonacci_asm");
  __asm volatile("mov	r3, r0");
  __asm volatile("add	r3, r4");
  __asm volatile("stop:");
  __asm volatile("mov	r0, r3");
  __asm volatile("adds	r7, #12");
  __asm volatile("mov	sp, r7");
  __asm volatile("pop	{r4, r7, pc}");
}

int fibonacci_golden(int n){
  if(n <= 2) return 1;
  return fibonacci_golden(n-1)+fibonacci_golden(n-2);
}

int main(void){

  int x = 10;
  int y_asm = fibonacci_asm(x);
  int y_golden = fibonacci_golden(x);  

  #ifdef KLEE
  printf("fibonacci1(%d) = %d\n",x,y_asm);
  printf("fibonacci_golden(%d) = %d\n",x,y_golden);
  assert(y_asm == y_golden);
  printf("ok\n\n");
  #endif
}
