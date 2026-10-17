# Package path hardening — 2026-10-16

Actual combined stdout/stderr:

* `suite.log`: `make test-sxpkg test-sxpkg-wrapper test-sxpkg-polish test-sxpkg-online-local test-sxpkg-online-optin`
* `doctor.log`: `make doctor`
* `true-selfhost.log`: `make true-selfhost`
* `gen3.log`: `make gen3`
* `native-test.log`: `make native-test`

These commands ran in that order in one `&&` chain, which exited zero.
`focused.log` is a subsequent direct successful run of
`sh selfhost/test_sxpkg_transfer_hardening.sh` against the built .sa binary.
The hardening script also ran inside the package suite and true-selfhost.
Gen3/gen4 were byte-identical.

Transfers use local files, successful mock curl/wget, or intentional failing
stubs. No real DNS or transport was used. The wget-only PATH exposes only the
stub and required shell utilities; real curl/wget are unreachable there.
No interpreter, cryptographic integrity, signatures, trust policy or provenance
mechanism was added. The fetched checksum detects later accidental edits only.
