#ifndef SAYANOX_RC_RUNTIME_H
#define SAYANOX_RC_RUNTIME_H
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
typedef struct SxRcStr { size_t refs; size_t size; char data[]; } SxRcStr;
static SxRcStr *sx_rc_from(const char *p){return p?(SxRcStr*)((char*)p-sizeof(SxRcStr)):NULL;}
static char *sx_rc_new(size_t n){SxRcStr*h=malloc(sizeof(*h)+n+1);if(!h)abort();h->refs=1;h->size=n;h->data[n]=0;return h->data;}
static void sx_rc_retain(const char*p){if(p){SxRcStr*h=sx_rc_from(p);if(!h->refs)abort();++h->refs;}}
static void sx_rc_release(const char*p){if(p){SxRcStr*h=sx_rc_from(p);if(!h->refs)abort();if(--h->refs==0)free(h);}}
static char *sx_concat(const char*a,const char*b){size_t x=strlen(a),y=strlen(b);char*r=sx_rc_new(x+y);memcpy(r,a,x);memcpy(r+x,b,y);return r;}
#endif
