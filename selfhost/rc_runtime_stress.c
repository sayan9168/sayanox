#include "rc_runtime.h"
int main(void){
  char *s=sx_rc_new(5); memcpy(s,"start",5); sx_rc_retain(s); sx_rc_release(s);
  for(int i=0;i<2000;i++){ char *n=sx_concat(s,"x"); sx_rc_release(s); s=n; }
  printf("%zu\n",sx_rc_from(s)->size);
  puts("gc-rc-ok");
  sx_rc_release(s);
  return 0;
}
