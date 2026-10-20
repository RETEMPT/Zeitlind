"""Read-only source directory audit. Fetches text; never executes remote scripts."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import json
from pathlib import Path
import re
from urllib.request import Request, urlopen
from urllib.parse import urljoin

DEFAULT = 'https://raw.githubusercontent.com/venera-app/venera-configs/main/index.json'
SAMPLES = {'komga', 'kavita', 'manga_dex', 'Komiic', 'ccc', 'comic_walker', 'shonen_jump_plus'}


def fetch(address):
    request = Request(address, headers={'User-Agent': 'Zeitlind-source-audit/2.0'})
    with urlopen(request, timeout=20) as response:
        content = response.read(4 * 1024 * 1024 + 1)
        if len(content) > 4 * 1024 * 1024:
            raise ValueError('Response exceeds 4 MiB')
        return content.decode('utf-8-sig')


def audit(entry, directory):
    address = urljoin(directory, entry.get('url') or entry['fileName'])
    result = {'name': entry['name'], 'key': entry['key'],
              'version': entry['version'], 'script_url': address}
    try:
        script = fetch(address)
        result['script_downloaded'] = True
        result['declares_comic_source'] = bool(re.search(r'class\s+\w+\s+extends\s+ComicSource', script))
        result['key_matches'] = bool(re.search(r'\bkey\s*=\s*[\'"]' + re.escape(entry['key']) + r'[\'"]', script))
        result['bytes'] = len(script.encode('utf-8'))
    except Exception as error:
        result['script_downloaded'] = False
        result['error'] = str(error)
    result['reading_verified'] = False
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', default=DEFAULT)
    parser.add_argument('--output', default='doc/source-check.json')
    parser.add_argument('--all', action='store_true', help='Check every listed script instead of the sample set')
    args = parser.parse_args()
    entries = json.loads(fetch(args.directory))
    selected = entries if args.all else [entry for entry in entries if entry['key'] in SAMPLES]
    with ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(lambda entry: audit(entry, args.directory), selected))
    report = {
        'checked_at_utc': datetime.now(timezone.utc).isoformat(),
        'directory_url': args.directory,
        'directory_entry_count': len(entries),
        'scope': 'Directory and script transport/metadata only. No login, script execution or comic reading tested.',
        'sources': results,
    }
    destination = Path(args.output)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f"Directory: {len(entries)} entries; downloaded {sum(r['script_downloaded'] for r in results)}/{len(results)} checked scripts. Report: {destination}")


if __name__ == '__main__':
    main()
