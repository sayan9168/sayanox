/*
 * Sayanox minimal native AOT (Linux x86_64 ELF) — no clang for the output binary.
 * Supports: repeated `show <integer>` (best-effort scan).
 * Usage: ./selfhost/native_aot input.sa output_bin
 */
#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#define MAX_SHOWS 64
#define MAX_SRC (1 << 20)

static char *read_file(const char *path, size_t *out_n) {
  FILE *f = fopen(path, "rb");
  if (!f) { perror(path); exit(1); }
  fseek(f, 0, SEEK_END);
  long n = ftell(f);
  fseek(f, 0, SEEK_SET);
  if (n < 0 || n > MAX_SRC) { fprintf(stderr, "native_aot: file too large\n"); exit(1); }
  char *b = malloc((size_t)n + 1);
  if (!b) exit(1);
  if (n && fread(b, 1, (size_t)n, f) != (size_t)n) exit(1);
  b[n] = 0;
  fclose(f);
  *out_n = (size_t)n;
  return b;
}

static int collect_shows(const char *src, long *vals, int maxv) {
  int n = 0;
  const char *p = src;
  while (*p && n < maxv) {
    if ((p == src || !isalnum((unsigned char)p[-1])) &&
        p[0] == 's' && p[1] == 'h' && p[2] == 'o' && p[3] == 'w' &&
        !isalnum((unsigned char)p[4])) {
      p += 4;
      while (*p == ' ' || *p == '\t') p++;
      if (isdigit((unsigned char)*p)) {
        long v = 0;
        while (isdigit((unsigned char)*p)) { v = v * 10 + (*p - '0'); p++; }
        vals[n++] = v;
        continue;
      }
    }
    p++;
  }
  return n;
}

static size_t build_msg(long *vals, int nv, char *msg, size_t cap) {
  size_t pos = 0;
  for (int i = 0; i < nv; i++) {
    char tmp[32];
    int m = snprintf(tmp, sizeof(tmp), "%ld\n", vals[i]);
    if (m < 0 || pos + (size_t)m >= cap) break;
    memcpy(msg + pos, tmp, (size_t)m);
    pos += (size_t)m;
  }
  return pos;
}

#pragma pack(push, 1)
typedef struct {
  unsigned char e_ident[16];
  uint16_t e_type, e_machine;
  uint32_t e_version;
  uint64_t e_entry, e_phoff, e_shoff;
  uint32_t e_flags;
  uint16_t e_ehsize, e_phentsize, e_phnum, e_shentsize, e_shnum, e_shstrndx;
} Elf64_Ehdr;
typedef struct {
  uint32_t p_type, p_flags;
  uint64_t p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_align;
} Elf64_Phdr;
#pragma pack(pop)

static void emit_elf(const char *out_path, const char *msg, size_t msg_len) {
  const uint64_t base = 0x400000;
  size_t hdr = sizeof(Elf64_Ehdr) + sizeof(Elf64_Phdr);
  unsigned char code[64];
  size_t c = 0;
  code[c++] = 0x48; code[c++] = 0xc7; code[c++] = 0xc0; code[c++] = 0x01; code[c++] = 0; code[c++] = 0; code[c++] = 0;
  code[c++] = 0x48; code[c++] = 0xc7; code[c++] = 0xc7; code[c++] = 0x01; code[c++] = 0; code[c++] = 0; code[c++] = 0;
  size_t lea_disp_at = c + 3;
  code[c++] = 0x48; code[c++] = 0x8d; code[c++] = 0x35;
  code[c++] = 0; code[c++] = 0; code[c++] = 0; code[c++] = 0;
  code[c++] = 0x48; code[c++] = 0xc7; code[c++] = 0xc2;
  uint32_t ml = (uint32_t)msg_len;
  memcpy(code + c, &ml, 4); c += 4;
  code[c++] = 0x0f; code[c++] = 0x05;
  code[c++] = 0x48; code[c++] = 0xc7; code[c++] = 0xc0; code[c++] = 0x3c; code[c++] = 0; code[c++] = 0; code[c++] = 0;
  code[c++] = 0x48; code[c++] = 0x31; code[c++] = 0xff;
  code[c++] = 0x0f; code[c++] = 0x05;

  size_t code_off = hdr;
  size_t msg_off = code_off + c;
  size_t file_sz = msg_off + msg_len;
  uint64_t rip_next = base + code_off + lea_disp_at + 4;
  uint64_t msg_va = base + msg_off;
  int32_t disp = (int32_t)(msg_va - rip_next);
  memcpy(code + lea_disp_at, &disp, 4);

  Elf64_Ehdr eh;
  memset(&eh, 0, sizeof(eh));
  eh.e_ident[0] = 0x7f; eh.e_ident[1] = 'E'; eh.e_ident[2] = 'L'; eh.e_ident[3] = 'F';
  eh.e_ident[4] = 2; eh.e_ident[5] = 1; eh.e_ident[6] = 1;
  eh.e_type = 2; eh.e_machine = 62; eh.e_version = 1;
  eh.e_entry = base + code_off;
  eh.e_phoff = sizeof(Elf64_Ehdr);
  eh.e_ehsize = sizeof(Elf64_Ehdr);
  eh.e_phentsize = sizeof(Elf64_Phdr);
  eh.e_phnum = 1;

  Elf64_Phdr ph;
  memset(&ph, 0, sizeof(ph));
  ph.p_type = 1; ph.p_flags = 5;
  ph.p_offset = 0; ph.p_vaddr = base; ph.p_paddr = base;
  ph.p_filesz = file_sz; ph.p_memsz = file_sz; ph.p_align = 0x1000;

  FILE *o = fopen(out_path, "wb");
  if (!o) { perror(out_path); exit(1); }
  fwrite(&eh, 1, sizeof(eh), o);
  fwrite(&ph, 1, sizeof(ph), o);
  fwrite(code, 1, c, o);
  fwrite(msg, 1, msg_len, o);
  fclose(o);
  chmod(out_path, 0755);
}

int main(int argc, char **argv) {
  if (argc < 3) {
    fprintf(stderr, "Usage: native_aot <input.sa> <output_bin>\n");
    fprintf(stderr, "Linux x86_64 native backend MVP. Supports: show <int>\n");
    return 1;
  }
  size_t n = 0;
  char *src = read_file(argv[1], &n);
  long vals[MAX_SHOWS];
  int nv = collect_shows(src, vals, MAX_SHOWS);
  free(src);
  if (nv == 0) {
    fprintf(stderr, "native_aot: no `show <integer>` in %s\n", argv[1]);
    return 1;
  }
  char msg[4096];
  size_t ml = build_msg(vals, nv, msg, sizeof(msg));
  emit_elf(argv[2], msg, ml);
  printf("native_aot: %s -> %s (%d show(s), no clang)\n", argv[1], argv[2], nv);
  return 0;
}
