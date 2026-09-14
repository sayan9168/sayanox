#!/usr/bin/env python3
"""Emit strcmp-based equality for string expressions in Stage-2 output."""
from pathlib import Path
import re

path = Path("selfhost/stage2_template.c")
src = path.read_text()

helper = r'''static int is_str_expr(const char *e){if(!e)return 0;if(e[0]=='"')return 1;if(strstr(e,"sx_concat")||strstr(e,"sx_str")||strstr(e,"sx_read_file")||strstr(e,"sx_upper")||strstr(e,"sx_lower")||strstr(e,"sx_trim")||strstr(e,"sx_char_at")||strstr(e,"sx_char_from_code"))return 1;for(int i=0;i<g_nstrs;i++)if(!strcmp(g_str_names[i],e))return 1;return 0;}\n'''
marker = 'static char *parse_expr(void);'
if 'static int is_str_expr(' not in src:
    src = src.replace(marker, helper + marker, 1)

pattern = re.compile(r"static char \*parse_cmp\(void\)\{.*?\nstatic char \*parse_expr", re.S)
replacement = r'''static char *parse_cmp(void){char *left=parse_add();if(check(T_EQ)||check(T_NEQ)||check(T_LT)||check(T_GT)||check(T_LTE)||check(T_GTE)){TokKind k=cur()->kind;advance();char *right=parse_add();char *n=malloc(900);if((k==T_EQ||k==T_NEQ)&&is_str_expr(left)&&is_str_expr(right)){snprintf(n,900,"(strcmp(%s,%s)%s0)",left,right,k==T_EQ?"==":"!=");}else{const char *op=k==T_EQ?"==":k==T_NEQ?"!=":k==T_LT?"<":k==T_GT?">":k==T_LTE?"<=":">=";snprintf(n,900,"(%s %s %s)",left,op,right);}free(left);free(right);return n;}return left;}
static char *parse_expr'''
src, count = pattern.subn(lambda _m: replacement, src, count=1)
if count != 1:
    raise SystemExit("Stage-2 parse_cmp function was not found")

path.write_text(src)
print("Patched Stage-2 string comparisons")
