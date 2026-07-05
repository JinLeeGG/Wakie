#!/usr/bin/env python3
"""Prepend a release <item> into the appcast feed.

Driven by env vars the CI release workflow sets (SHORT, BUILD, SIG, TAG, REPO);
APPCAST points at the feed file to edit. Kept as a file (not an inline CI
heredoc) so it's testable and immune to YAML indentation quirks.
"""
import email.utils
import os

MARKER = "<!-- APPCAST:INSERT -->"


def item_xml(env: dict) -> str:
    repo, tag = env["REPO"], env["TAG"]
    url = f"https://github.com/{repo}/releases/download/{tag}/WakieAI.dmg"
    return f"""    <item>
      <title>{env['SHORT']}</title>
      <sparkle:version>{env['BUILD']}</sparkle:version>
      <sparkle:shortVersionString>{env['SHORT']}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>10.15</sparkle:minimumSystemVersion>
      <pubDate>{email.utils.formatdate(usegmt=True)}</pubDate>
      <description><![CDATA[ See https://github.com/{repo}/releases/tag/{tag} ]]></description>
      <enclosure url="{url}" {env['SIG']} type="application/octet-stream" />
    </item>"""


def main() -> None:
    path = os.environ.get("APPCAST", "/tmp/site/appcast.xml")
    text = open(path).read()
    if MARKER not in text:
        raise SystemExit(f"marker {MARKER!r} not found in {path}")
    item = item_xml(os.environ)
    open(path, "w").write(text.replace(MARKER, MARKER + "\n" + item, 1))
    print(f"appcast updated: {os.environ['SHORT']} (build {os.environ['BUILD']})")


if __name__ == "__main__":
    main()
