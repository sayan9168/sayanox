/* Apply static type-checker patches onto stage2_template.c */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *readf(const char *p) {
  FILE *f = fopen(p, "rb");
  if (!f) return NULL;
  fseek(f, 0, SEEK_END);
  long n = ftell(f);
  fseek(f, 0, SEEK_SET);
  char *t = malloc((size_t)n + 1);
  if (!t) exit(1);
  fread(t, 1, (size_t)n, f);
  t[n] = 0;
  fclose(f);
  return t;
}

static int replace1(char **t, const char *old, const char *neu) {
  char *p = strstr(*t, old);
  if (!p) return 0;
  size_t lo = strlen(old), ln = strlen(neu), L = strlen(*t);
  size_t off = (size_t)(p - *t);
  char *n = malloc(L - lo + ln + 1);
  if (!n) exit(1);
  memcpy(n, *t, off);
  memcpy(n + off, neu, ln);
  memcpy(n + off + ln, p + lo, L - off - lo + 1);
  free(*t);
  *t = n;
  return 1;
}

int main(void) {
  char *t = readf("selfhost/stage2_template.c");
  if (!t) {
    fprintf(stderr, "inject_types: cannot open stage2_template.c\n");
    return 1;
  }
  if (strstr(t, "expr_kind") && strstr(t, "type_err2")) {
    puts("inject_types: already present");
    free(t);
    return 0;
  }

  const char *old_decl =
      "static int is_declared(const char *n){for(int i=0;i<g_ndecl;i++)if(!strcmp(g_decl_names[i],n))return 1;return 0;}";
  const char *new_decl =
      "static int is_declared(const char *n){for(int i=0;i<g_ndecl;i++)if(!strcmp(g_decl_names[i],n))return 1;return 0;}"
      "static int looks_string(const char *e);static int looks_list(const char *e);static int looks_struct(const char *e);"
      "static int get_decl_kind(const char *n){for(int i=0;i<g_ndecl;i++)if(!strcmp(g_decl_names[i],n))return g_decl_kind[i];return -1;}"
      "static const char *type_name(int k){if(k==0)return \"number\";if(k==1)return \"string\";if(k==2)return \"list\";if(k==3)return \"struct\";return \"unknown\";}"
      "static int expr_kind(const char *e){if(!e)return 0;if(looks_list(e))return 2;if(looks_struct(e))return 3;if(looks_string(e))return 1;{int k=get_decl_kind(e);if(k>=0)return k;}return 0;}"
      "static void type_err(const char *ctx,int expect,int got){fprintf(stderr,\"stage2: %s:%d: type error: %s: expected %s, got %s\\n\",g_path?g_path:\"input\",(g_ti<g_ntok)?g_toks[g_ti].line:g_line,ctx,type_name(expect),type_name(got));exit(1);}"
      "static void type_err2(const char *ctx,const char *detail){fprintf(stderr,\"stage2: %s:%d: type error: %s: %s\\n\",g_path?g_path:\"input\",(g_ti<g_ntok)?g_toks[g_ti].line:g_line,ctx,detail);exit(1);}";
  if (!replace1(&t, old_decl, new_decl)) {
    fprintf(stderr, "inject_types: is_declared not found\n");
    return 1;
  }

  replace1(&t,
           "strstr(e,\"sx_trim\")?1:0;}",
           "strstr(e,\"sx_trim\")||strstr(e,\"sx_chr\")||strstr(e,\"sx_substr\")||strstr(e,\"sx_arg(\")?1:0;}");

  replace1(&t,
           "char *right=parse_primary();char *n=malloc(900);if(op=='%')",
           "char *right=parse_primary();int kl=expr_kind(left),kr=expr_kind(right);if(kl!=0||kr!=0)type_err2(\"*/%\",\"both operands must be numbers\");char *n=malloc(900);if(op=='%')");

  const char *old_add =
      "static char *parse_add(void){char *left=parse_term();while(check(T_PLUS)||check(T_MINUS)){char op=check(T_PLUS)?'+':'-';advance();char *right=parse_term();char *n=malloc(900);snprintf(n,900,\"(%s %c %s)\",left,op,right);free(left);free(right);left=n;}return left;}";
  const char *new_add =
      "static char *parse_add(void){char *left=parse_term();while(check(T_PLUS)||check(T_MINUS)){char op=check(T_PLUS)?'+':'-';advance();char *right=parse_term();int kl=expr_kind(left),kr=expr_kind(right);if(op=='+'&&(kl==1||kr==1)){if(kl!=1||kr!=1)type_err(\"string +\",1,kl==1?kr:kl);char *n=malloc(900);snprintf(n,900,\"sx_concat(%s,%s)\",left,right);free(left);free(right);left=n;continue;}if(kl!=0||kr!=0)type_err2(op=='+'?\"+\":\"-\",\"both operands must be numbers\");char *n=malloc(900);snprintf(n,900,\"(%s %c %s)\",left,op,right);free(left);free(right);left=n;}return left;}";
  if (!replace1(&t, old_add, new_add))
    fprintf(stderr, "inject_types: warn parse_add\n");

  replace1(&t,
           "char *right=parse_add();char *n=malloc(900);snprintf(n,900,\"(%s %s %s)\",left,op,right);",
           "char *right=parse_add();int kl=expr_kind(left),kr=expr_kind(right);if(kl!=kr)type_err(\"comparison\",kl,kr);char *n=malloc(900);snprintf(n,900,\"(%s %s %s)\",left,op,right);");

  replace1(&t,
           "else snprintf(call,900,\"sx_%s(%s)\",buf,args);free(buf);return call;}return buf;}",
           "else snprintf(call,900,\"sx_%s(%s)\",buf,args);free(buf);return call;}if(!is_declared(buf)&&!is_list_name(buf)&&!is_struct_type(buf)){char msg[200];snprintf(msg,sizeof(msg),\"undefined variable '%s' (declare with hold first)\",buf);type_err2(\"name\",msg);}return buf;}");

  replace1(&t, "if(looks_string(e))emit", "if(looks_string(e)||expr_kind(e)==1)emit");

  FILE *o = fopen("selfhost/stage2_template.c", "wb");
  if (!o) return 1;
  fputs(t, o);
  fclose(o);
  free(t);
  puts("inject_types: applied");
  return 0;
}
