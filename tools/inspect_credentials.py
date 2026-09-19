#!/usr/bin/env python3
"""Describe the stored device credentials without revealing them.

    uv run python tools/inspect_credentials.py [path/to/credentials.json]

`GetListOfOwnedDevices` answering 403 "Couldn't decrypt the request's signature
using the device info's public key" is a statement about the key and the shape
of the signature block, not about what was signed — so what matters is the key's
size, how the PEM is framed, and whether the DER parses the way the app's parser
reads it. This prints those facts and nothing else: no key material, no token.
"""

import base64
import json
import re
import sys
from pathlib import Path

DEFAULT = (
    Path.home()
    / "Library/Containers/dev.stkn.kindbeamer/Data/Library/Application Support"
    / "dev.stkn.kindbeamer/credentials.json"
)


def read_der_int(der: bytes, pos: int) -> tuple[int, int]:
    """Read one DER INTEGER the way lib/src/amazon/signer.dart reads it."""
    tag = der[pos]
    pos += 1
    length = der[pos]
    pos += 1
    if length & 0x80:
        count = length & 0x7F
        length = int.from_bytes(der[pos : pos + count], "big")
        pos += count
    if tag != 0x02:
        raise ValueError(f"expected INTEGER, got tag 0x{tag:02x}")
    return int.from_bytes(der[pos : pos + length], "big"), pos + length


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT
    if not path.exists():
        sys.exit(f"no credentials at {path}")

    info = json.loads(path.read_text())["device_info"]
    pem = info["device_private_key"]
    token = info["adp_token"]

    header = re.search(r"-----BEGIN ([A-Z ]+)-----", pem)
    print(f"file:            {path}")
    print(f"PEM header:      {header.group(1) if header else 'none'}")
    line_ends = "CRLF" if "\r\n" in pem else "LF"
    print(f"PEM line ends:   {line_ends}")

    body = "".join(
        line for line in pem.splitlines() if line and not line.startswith("-----")
    )
    der = base64.b64decode(body)

    pos = 0
    if der[pos] != 0x30:
        sys.exit(f"expected SEQUENCE, got tag 0x{der[pos]:02x}")
    pos += 1
    length = der[pos]
    pos += 1
    if length & 0x80:
        pos += length & 0x7F

    version, pos = read_der_int(der, pos)
    n, pos = read_der_int(der, pos)
    e, pos = read_der_int(der, pos)
    d, pos = read_der_int(der, pos)

    key_bytes = (n.bit_length() + 7) // 8
    print(f"DER version:     {version}")
    print(f"modulus:         {n.bit_length()} bits ({key_bytes} bytes)")
    print(f"public exponent: {e}")
    print(f"private exp:     {d.bit_length()} bits")
    print(f"block the app builds: 256 bytes (0x01 + 0xFF*222 + 0x00 + 32-byte digest)")
    print(
        "block vs modulus:     "
        + ("match" if key_bytes == 256 else f"MISMATCH — key wants {key_bytes} bytes")
    )

    # Does the keypair actually round-trip? pow(pow(x, d, n), e, n) == x
    probe = 0xDEADBEEF
    round_trip = pow(pow(probe, d, n), e, n) == probe
    print(f"key round-trips: {round_trip}")

    print(f"adp_token:       {len(token)} chars")
    fields = re.findall(r"\{(\w+):", token)
    print(f"adp_token parts: {', '.join(fields) if fields else 'unstructured'}")
    whitespace = "contains whitespace" if re.search(r"\s", token) else "clean"
    print(f"adp_token ws:    {whitespace}")


if __name__ == "__main__":
    main()
