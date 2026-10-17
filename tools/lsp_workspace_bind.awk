# Tool-local native binding, not a general FFI or language extension.
# Replace only the exact generated fallback; fail closed if its shape changes.
/^static char \*workspace_manifest\(char \*root\) \{$/ {
    found++
    print "#include \"lsp_workspace.h\""
    print
    print "  return sx_lsp_workspace_manifest(root);"
    inside=1
    next
}
inside {
    if ($0 == "  return \"\";") { returns++; next }
    if ($0 == "}") { print; inside=0; next }
    bad=1
    next
}
{ print }
END {
    if(found!=1 || returns!=1 || inside || bad) {
        print "LSP workspace binding: unexpected generated fallback shape" > "/dev/stderr"
        exit 1
    }
}
