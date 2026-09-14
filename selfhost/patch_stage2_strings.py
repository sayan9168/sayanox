#!/usr/bin/env python3
"""Harden Stage-2 string literal emission for self-hosted source programs."""
from pathlib import Path
import re

path = Path("selfhost/stage2_template.c")
src = path.read_text()

pattern = re.compile(r"if\(check\(T_STRING\)\)\{.*?return buf;\}", re.S)
replacement = r'''if(check(T_STRING)){char esc[900];size_t ei=0;const unsigned char *s=(const unsigned char*)cur()->text;esc[ei++]='"';for(;*s&&ei+6<sizeof(esc);s++){unsigned char ch=*s;if(ch=='"'||ch=='\\'){esc[ei++]='\\';esc[ei++]=(char)ch;}else if(ch=='\n'){esc[ei++]='\\';esc[ei++]='n';}else if(ch=='\r'){esc[ei++]='\\';esc[ei++]='r';}else if(ch=='\t'){esc[ei++]='\\';esc[ei++]='t';}else if(ch=='\b'){esc[ei++]='\\';esc[ei++]='b';}else if(ch=='\f'){esc[ei++]='\\';esc[ei++]='f';}else if(ch<32){static const char hex[]="0123456789ABCDEF";esc[ei++]='\\';esc[ei++]='x';esc[ei++]=hex[(ch>>4)&15];esc[ei++]=hex[ch&15];}else esc[ei++]=(char)ch;}esc[ei++]='"';esc[ei]=0;snprintf(buf,900,"%s",esc);advance();return buf;}'''

src, count = pattern.subn(lambda _match: replacement, src, count=1)
if count != 1:
    raise SystemExit("Stage-2 string parser block was not found")

path.write_text(src)
print("Patched Stage-2 string literal emission")
