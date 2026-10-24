#!/usr/bin/env python3
"""Insert a release into the Sparkle appcast and the website changelog.

Called by the release workflow once per tagged release. It:
  - prepends a new <item> to appcast.xml, newest first, carrying the Sparkle
    EdDSA signature the workflow already produced, and
  - prepends the same release to changelog.json for the website.

Both files live on the gh-pages branch. Running it again for a version that's
already there does nothing, so a re-run of the workflow can't add duplicates.
"""
import argparse
import datetime
import html
import json


def md_to_html(md: str) -> str:
    """Release notes from Markdown to HTML: `- ` bullets become a list, other
    lines become paragraphs. Sparkle shows the <description> as HTML."""
    out, in_list = [], False
    for raw in md.strip().splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith(("- ", "* ")):
            if not in_list:
                out.append("<ul>")
                in_list = True
            out.append("<li>%s</li>" % html.escape(line[2:].strip()))
        else:
            if in_list:
                out.append("</ul>")
                in_list = False
            out.append("<p>%s</p>" % html.escape(line))
    if in_list:
        out.append("</ul>")
    return "\n".join(out) if out else "<p>Update.</p>"


def update_appcast(path: str, version: str, build: str, min_system: str,
                   url: str, sparkle_attrs: str, pubdate: str, notes_html: str) -> None:
    with open(path, encoding="utf-8") as f:
        appcast = f.read()

    tag = "<sparkle:shortVersionString>%s</sparkle:shortVersionString>" % version
    if tag in appcast:
        print("appcast already has %s, skipping" % version)
        return

    item = (
        "        <item>\n"
        "            <title>%s</title>\n"
        "            <pubDate>%s</pubDate>\n"
        "            <sparkle:version>%s</sparkle:version>\n"
        "            <sparkle:shortVersionString>%s</sparkle:shortVersionString>\n"
        "            <sparkle:minimumSystemVersion>%s</sparkle:minimumSystemVersion>\n"
        "            <description><![CDATA[\n%s\n]]></description>\n"
        '            <enclosure url="%s" %s type="application/octet-stream"/>\n'
        "        </item>\n"
    ) % (version, pubdate, build, version, min_system, notes_html, url, sparkle_attrs)

    marker = "</language>"
    idx = appcast.find(marker)
    if idx == -1:
        raise SystemExit("appcast.xml is missing the <language> element")
    at = idx + len(marker)
    appcast = appcast[:at] + "\n" + item + appcast[at:]
    with open(path, "w", encoding="utf-8") as f:
        f.write(appcast)
    print("appcast: inserted %s" % version)


def update_changelog(path: str, version: str, build: str, notes_md: str) -> None:
    try:
        with open(path, encoding="utf-8") as f:
            entries = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        entries = []

    if any(e.get("version") == version for e in entries):
        print("changelog already has %s, skipping" % version)
        return

    date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
    entries.insert(0, {
        "version": version,
        "build": build,
        "date": date,
        "notes": notes_md.strip(),
    })
    with open(path, "w", encoding="utf-8") as f:
        json.dump(entries, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("changelog: inserted %s" % version)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--appcast", required=True)
    ap.add_argument("--changelog", required=True)
    ap.add_argument("--version", required=True, help="short version, e.g. 1.2.0")
    ap.add_argument("--build", required=True, help="CFBundleVersion (monotonic)")
    ap.add_argument("--min-system", required=True, help="e.g. 26.5")
    ap.add_argument("--url", required=True, help="download URL for the .dmg")
    ap.add_argument("--sparkle-attrs", required=True,
                    help='e.g. sparkle:edSignature="..." length="..."')
    ap.add_argument("--pubdate", required=True, help="RFC 822 date")
    ap.add_argument("--notes-file", required=True)
    a = ap.parse_args()

    with open(a.notes_file, encoding="utf-8") as f:
        notes_md = f.read()

    update_appcast(a.appcast, a.version, a.build, a.min_system, a.url,
                   a.sparkle_attrs, a.pubdate, md_to_html(notes_md))
    update_changelog(a.changelog, a.version, a.build, notes_md)


if __name__ == "__main__":
    main()
