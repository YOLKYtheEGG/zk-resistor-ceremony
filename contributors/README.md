# Contributors

Signed attestations, one per contributor as `<name>.attestation.md`. Each declares the stage and slot the contributor filled and that they destroyed their random entropy. The file hashes themselves live in `transcript/contributions.json`.

Combined with the cryptographic chain in the transcript, these attestations are what give the ceremony its trust property.

`scripts/contribute.sh` drafts the attestation for you to sign. See [CONTRIBUTING.md](../CONTRIBUTING.md).

## Verifying an attestation

GPG clearsigned:

```bash
gpg --verify contributors/<name>.attestation.md
```

GitHub-signed commit:

```bash
git log --show-signature contributors/<name>.attestation.md
```
