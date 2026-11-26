import csv
import sys
import urllib.request
from html.parser import HTMLParser


class LinkCollector(HTMLParser):
    """Collects the href of every link on a page."""

    def __init__(self):
        super().__init__()
        self.links = []

    def handle_starttag(self, tag, attrs):
        if tag != "a":
            return
        for name, value in attrs:
            if name == "href" and value and not value.startswith("#"):
                self.links.append(value)  # relative links kept as is


def fetch(url: str, timeout: float = 10.0) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": "link-report/1.0"})  # some sites block the default
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read().decode("utf-8", errors="replace")


def main(urls):
    writer = csv.writer(sys.stdout)
    writer.writerow(["page", "link"])  # header row
    for url in urls:
        collector = LinkCollector()
        collector.feed(fetch(url))
        for link in collector.links:
            writer.writerow([url, link])


if __name__ == "__main__":
    main(sys.argv[1:])
