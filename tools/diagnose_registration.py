#!/usr/bin/env python3
"""Probe FirsProxy/registerDeviceWithToken with one sign-in.

    uv run --with requests python tools/diagnose_registration.py

Device registration answers HTTP 200 with
`<error><message>Internal Error</message></error>` when it dislikes something,
and the message never says what. One authorization code buys one access token,
but that token is good for many registration attempts — so this asks for a
single interactive sign-in and then tries the variants against it, printing what
each one gets back.

Credentials in the responses (`device_private_key`, `adp_token`,
`store_authentication_cookie`) are replaced with their length before printing.
"""

import argparse
import base64
import binascii
import hashlib
import os
import re
import sys
import urllib.parse
from pathlib import Path

import requests

CLIENT_ID = "658490dfb190e494030082836775981fa23be0c2425441860352ba0f55915b43002d"
DEVICE_TYPE = "A1K6D1WRW0MALS"
REFERENCE_SERIAL = "ZYSQ37GQ5JQDAIKDZ3WYH6I74MJCVEGG"
REFERENCE_PID = "D21NN3GG"
RETURN_TO = {
    "maplanding": "https://www.amazon.com/sendtokindle/maplanding",
    "gp": "https://www.amazon.com/gp/sendtokindle",
}
SECRET_TAGS = ("device_private_key", "adp_token", "store_authentication_cookie")


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode().rstrip("=")


def signin_url(verifier: str, return_to: str) -> str:
    challenge = b64url(hashlib.sha256(verifier.encode()).digest())
    q = {
        "openid.claimed_id": "http://specs.openid.net/auth/2.0/identifier_select",
        "openid.ns.oa2": "http://www.amazon.com/ap/ext/oauth/2",
        "openid.ns": "http://specs.openid.net/auth/2.0",
        "openid.identity": "http://specs.openid.net/auth/2.0/identifier_select",
        "openid.oa2.client_id": f"device:{CLIENT_ID}",
        "openid.mode": "checkid_setup",
        "openid.oa2.scope": "device_auth_access",
        "openid.oa2.response_type": "code",
        "openid.oa2.code_challenge": challenge,
        "openid.oa2.code_challenge_method": "S256",
        "openid.return_to": return_to,
        "openid.ns.pape": "http://specs.openid.net/extensions/pape/1.0",
        "openid.pape.max_auth_age": "0",
        "accountStatusPolicy": "P1",
        "openid.assoc_handle": "amzn_device_na",
        "pageId": "amzn_device_common_dark",
        "disableLoginPrepopulate": "1",
    }
    return "https://www.amazon.com/ap/signin?" + urllib.parse.urlencode(q)


def token_exchange(code: str, verifier: str) -> str:
    res = requests.post(
        "https://api.amazon.com/auth/token",
        json={
            "app_name": "Unknown",
            "client_domain": "DeviceLegacy",
            "client_id": CLIENT_ID,
            "code_algorithm": "SHA-256",
            "code_verifier": verifier,
            "requested_token_type": "access_token",
            "source_token": code,
            "source_token_type": "authorization_code",
        },
        headers={
            "Accept-Language": "en-US",
            "x-amzn-identity-auth-domain": "api.amazon.com",
            "User-Agent": "Mozilla/5.0",
        },
        timeout=30,
    )
    if res.status_code != 200:
        sys.exit(f"token exchange failed: HTTP {res.status_code} {res.text[:400]}")
    return res.json()["access_token"]


def generated_serial() -> str:
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    return "".join(alphabet[b % 32] for b in os.urandom(32))


PID_ALPHABET = "ABCDEFGHIJKLMNPQRSTUVWXYZ123456789"


def pid_for(serial: str) -> str:
    """The pid the service expects for `serial` (see device_id.dart)."""
    data = serial.encode()
    crc = (~binascii.crc32(data, -1)) & 0xFFFFFFFF
    folded = [0] * 8
    for i, byte in enumerate(data):
        folded[i % 8] ^= byte
    crc_bytes = [crc >> 24 & 0xFF, crc >> 16 & 0xFF, crc >> 8 & 0xFF, crc & 0xFF]
    out = ""
    for i in range(8):
        b = (folded[i] ^ crc_bytes[i & 3]) & 0xFF
        out += PID_ALPHABET[(b >> 7) + ((b >> 5 & 3) ^ (b & 0x1F))]
    return out


def build_body(serial: str, pid: str | None, software: str, model: str) -> str:
    pid_el = f"<pid>{pid}</pid>" if pid else ""
    return (
        "<?xml version='1.0' encoding='UTF-8'?>\n"
        "<request><parameters>"
        f"<deviceType>{DEVICE_TYPE}</deviceType>"
        f"<deviceSerialNumber>{serial}</deviceSerialNumber>"
        f"{pid_el}"
        "<authToken>{token}</authToken>"
        "<authTokenType>AccessToken</authTokenType>"
        f"<softwareVersion>{software}</softwareVersion>"
        "<os_version>MacOSX_10.14.6_x64</os_version>"
        f"<device_model>{model}</device_model>"
        "</parameters></request>"
    )


def redact(body: str) -> str:
    for tag in SECRET_TAGS:
        body = re.sub(
            f"<{tag}>(.*?)</{tag}>",
            lambda m, t=tag: f"<{t}>[{len(m.group(1))} chars]</{t}>",
            body,
            flags=re.S,
        )
    return body.replace("\n", " ")[:500]


def attempt(name: str, token: str, body_template: str, content_type: str) -> bool:
    body = body_template.format(token=token)
    res = requests.post(
        "https://firs-ta-g7g.amazon.com/FirsProxy/registerDeviceWithToken",
        data=body.encode(),
        headers={
            "Content-Type": content_type,
            "Expect": "",
            "Accept-Language": "en-US,*",
            "User-Agent": "Mozilla/5.0",
        },
        timeout=30,
    )
    ok = "device_private_key" in res.text
    print(f"\n=== {name}")
    print(f"    content-type: {content_type}")
    print(f"    HTTP {res.status_code} {'OK — credentials returned' if ok else ''}")
    print(f"    {redact(res.text)}")
    return ok


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--return-to", choices=sorted(RETURN_TO), default="gp")
    # A terminal in canonical mode drops input past ~1024 bytes per line, and
    # these redirect URLs are longer than that — pasting one at a prompt looks
    # like a keyboard that stopped working. Take it from a file instead.
    parser.add_argument("--redirect-file", help="file holding the redirect URL")
    parser.add_argument("--redirect-url", help="the redirect URL, quoted")
    args = parser.parse_args()

    verifier = b64url(os.urandom(32))
    print("Open this URL, sign in, then take the final URL from the address bar.")
    print("(It may bounce; the one carrying openid.oa2.authorization_code is it.)\n")
    print(signin_url(verifier, RETURN_TO[args.return_to]))

    if args.redirect_url:
        redirect = args.redirect_url.strip()
    elif args.redirect_file:
        redirect = Path(args.redirect_file).read_text().strip()
    else:
        print(
            "\nSave that URL to a file, then run again with"
            " --redirect-file <path> (a paste at a prompt is truncated at ~1024"
            " characters, and these URLs are longer)."
        )
        return

    code = urllib.parse.parse_qs(urllib.parse.urlparse(redirect).query).get(
        "openid.oa2.authorization_code", [""]
    )[0]
    if not code:
        sys.exit("no openid.oa2.authorization_code in that URL")

    token = token_exchange(code, verifier)
    print(f"\naccess token acquired ({len(token)} chars)\n")

    variants = [
        (
            "reference serial + pid, bare text/xml (what stkclient sends)",
            build_body(REFERENCE_SERIAL, REFERENCE_PID, "253", "Maxs MacBook Pro"),
            "text/xml",
        ),
        (
            "same, but text/xml; charset=utf-8",
            build_body(REFERENCE_SERIAL, REFERENCE_PID, "253", "Maxs MacBook Pro"),
            "text/xml; charset=utf-8",
        ),
        (
            "reference serial, no pid",
            build_body(REFERENCE_SERIAL, None, "253", "Maxs MacBook Pro"),
            "text/xml",
        ),
        (
            "generated serial + its derived pid (what the app now sends)",
            (lambda serial: build_body(serial, pid_for(serial), "253", "KindBeamer"))(
                generated_serial()
            ),
            "text/xml",
        ),
        (
            "generated serial + reference pid (known bad, kept as a control)",
            build_body(generated_serial(), REFERENCE_PID, "253", "KindBeamer"),
            "text/xml",
        ),
        (
            "generated serial, no pid",
            build_body(generated_serial(), None, "253", "KindBeamer"),
            "text/xml",
        ),
        (
            "reference pair, softwareVersion 260",
            build_body(REFERENCE_SERIAL, REFERENCE_PID, "260", "Maxs MacBook Pro"),
            "text/xml",
        ),
    ]

    for name, body, content_type in variants:
        if attempt(name, token, body, content_type):
            print("\nThis variant works — register with it.")
            return

    print("\nEvery variant was refused; the access token itself may be the problem.")


if __name__ == "__main__":
    main()
