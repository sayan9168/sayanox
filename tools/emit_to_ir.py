#!/usr/bin/env python3
"""emit_to_ir.py -- translate an SX_EMIT_LOG instruction list to the portable
IR listing documented in docs/NATIVE_IR.md.

Usage: python3 tools/emit_to_ir.py <emit.log> <out.ir>

What this is: a *reading and analysis* format. x86-64 registers become
abstract registers (rax->A, rcx->C, ..., xmmN->F<n>, rsp->SP, r12->BASE),
byte offsets become sequential instruction numbers, floating-point and
integer mnemonics are distinguished (addsd->FADD, add->IADD), and call
targets keep the names the emit log already gives them (`call make dbl`,
`call builtin shownum`). Phase markers, label slots and fixup lines are
preserved as comments.

What this is NOT: a second backend. Nothing assembles or executes the IR,
and no other ISA is targeted. An unrecognised mnemonic passes through
upper-cased with its operands register-renamed, so the listing stays a
faithful, complete transcription -- never a partial one that silently
drops instructions. The translation is a pure function of the log text:
same log, same IR, byte for byte.
"""
import re
import sys

REG = {
    "rax": "A", "eax": "A", "al": "A", "rcx": "C", "ecx": "C", "cl": "C",
    "rdx": "D", "edx": "D", "dl": "D", "rbx": "B", "ebx": "B", "bl": "B",
    "rsi": "SI", "esi": "SI", "sil": "SI", "rdi": "DI", "edi": "DI",
    "dil": "DI", "rsp": "SP", "esp": "SP", "rbp": "BP", "ebp": "BP",
    "r12": "BASE", "r12d": "BASE", "r13": "R13", "r13d": "R13",
    "r14": "R14", "r14d": "R14", "r15": "R15", "r15d": "R15",
    "rip": "PC",
}
for i in range(8, 12):
    REG["r%d" % i] = "R%d" % i
    REG["r%dd" % i] = "R%d" % i
    REG["r%db" % i] = "R%d" % i

MNEM = {
    "mov": "COPY", "movq": "COPY", "lea": "ADDR",
    "addsd": "FADD", "subsd": "FSUB", "mulsd": "FMUL", "divsd": "FDIV",
    "add": "IADD", "sub": "ISUB", "imul": "IMUL", "idiv": "IDIV",
    "and": "AND", "or": "OR", "xor": "XOR", "shl": "SHL", "shr": "SHR",
    "cmp": "ICMP", "test": "TEST", "ucomisd": "FCMP", "comisd": "FCMP",
    "push": "PUSH", "pop": "POP", "call": "CALL", "ret": "RET",
    "leave": "LEAVE", "jmp": "JMP", "nop": "NOP",
    "cvtsi2sd": "I2F", "cvttsd2si": "F2I",
    "movzx": "ZEXT", "movsx": "SEXT", "cdq": "CDQ", "cqo": "CQO",
    "seta": "SETA", "setae": "SETAE", "setb": "SETB", "setbe": "SETBE",
    "sete": "SETE", "setne": "SETNE", "setg": "SETG", "setge": "SETGE",
    "setl": "SETL", "setle": "SETLE",
}
for cc in ("a", "ae", "b", "be", "e", "ne", "g", "ge", "l", "le", "o", "no",
           "s", "ns", "p", "np"):
    MNEM["j" + cc] = "J" + cc.upper()

REG_TOKEN = re.compile(r"\b(xmm\d+|[a-z][a-z0-9]*d?|r\d+b?)\b")


def rename_regs(text):
    def sub(m):
        w = m.group(1)
        if w.startswith("xmm"):
            return "F" + w[3:]
        return REG.get(w, w)
    return REG_TOKEN.sub(sub, text)


def translate(lines):
    out = ["; portable IR listing (docs/NATIVE_IR.md) -- translated from an",
           "; SX_EMIT_LOG instruction list by tools/emit_to_ir.py. This is an",
           "; analysis format: no backend assembles or executes it."]
    n = 0
    for raw in lines:
        line = raw.rstrip("\n")
        if line.startswith(";"):
            out.append("; " + line[1:].strip())
            continue
        m = re.match(r"^[0-9a-f]{6}  (.*)$", line)
        if not m:
            # Never drop a line: carry it as a comment so a format change in
            # the emit log is visible here instead of silently lost.
            out.append("; UNTRANSLATED: " + line)
            continue
        ins = m.group(1).strip()
        parts = ins.split(None, 1)
        mnem = parts[0]
        ops = parts[1] if len(parts) > 1 else ""
        if mnem == "call" and ops:
            # `call builtin shownum` / `call make dbl`: keep the named target.
            out.append("I%-5d CALL %s" % (n, ops))
        else:
            op = MNEM.get(mnem, mnem.upper())
            out.append("I%-5d %s%s" % (n, op, (" " + rename_regs(ops)) if ops else ""))
        n += 1
    return out


def main(argv):
    if len(argv) != 3:
        sys.stderr.write("usage: emit_to_ir.py <emit.log> <out.ir>\n")
        return 2
    with open(argv[1], "r", encoding="utf-8", errors="replace") as f:
        lines = f.readlines()
    with open(argv[2], "w", encoding="utf-8") as f:
        f.write("\n".join(translate(lines)) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
