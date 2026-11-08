#!/usr/bin/env python3
"""Keep Ghostty's static background in sync with the selected macOS wallpaper."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import unquote, urlparse

HOME = Path.home()
BASE = Path(__file__).resolve().parent
OUTPUT = BASE / 'wallpaper.png'
INDEX = HOME / 'Library/Application Support/com.apple.wallpaper/Store/Index.plist'
CACHE = HOME / 'Library/Caches/ghostty-wallpaper'
AERIALS = HOME / 'Library/Application Support/com.apple.wallpaper/aerials/videos'
ENV = dict(os.environ, PATH='/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin')


def run(args, **kwargs):
    return subprocess.run(args, check=True, env=ENV, **kwargs)


def decoded(value):
    if isinstance(value, bytes):
        try:
            return decoded(plistlib.loads(value))
        except Exception:
            return None
    if isinstance(value, dict):
        return {k: decoded(v) for k, v in value.items()}
    if isinstance(value, list):
        return [decoded(v) for v in value]
    return value


def values(node, key):
    if isinstance(node, dict):
        for k, v in node.items():
            if k == key and isinstance(v, str):
                yield v
            yield from values(v, key)
    elif isinstance(node, list):
        for v in node:
            yield from values(v, key)


def desktop_image():
    script = """ObjC.import('AppKit');
const url = $.NSWorkspace.sharedWorkspace.desktopImageURLForScreen($.NSScreen.mainScreen);
url.isNil() ? '' : ObjC.unwrap(url.path);"""
    result = run(['/usr/bin/osascript', '-l', 'JavaScript', '-e', script],
                 capture_output=True, text=True).stdout.strip()
    return Path(result) if result else None


def selected_wallpaper():
    data = plistlib.loads(INDEX.read_bytes())
    linked = data.get('AllSpacesAndDisplays', {}).get('Linked', {}).get('Content', {})
    content = decoded(linked)
    providers = list(values(content, 'Provider'))
    if 'com.apple.wallpaper.choice.aerials' in providers:
        for asset in values(content, 'assetID'):
            movie = AERIALS / (asset + '.mov')
            if movie.is_file():
                return movie, True, content
        raise RuntimeError('所选 Apple 动态壁纸的视频尚未下载到本机')
    image = desktop_image()
    if not image or not image.is_file():
        # Some providers include the original image as a file URL in their choice.
        for url in values(content, 'relative'):
            if url.startswith('file:'):
                image = Path(unquote(urlparse(url).path))
                if image.is_file():
                    break
    if not image or not image.is_file():
        raise RuntimeError('无法找到当前桌面壁纸文件')
    return image, False, content


def reload_ghostty():
    script = '''if application "Ghostty" is running then
    tell application "Ghostty"
        if (count of windows) > 0 then
            perform action "reload_config" on focused terminal of selected tab of front window
        end if
    end tell
end if'''
    run(['/usr/bin/osascript', '-e', script], capture_output=True, text=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--force', action='store_true')
    parser.add_argument('--sigma', type=float, default=30)
    args = parser.parse_args()
    CACHE.mkdir(parents=True, exist_ok=True)
    with (CACHE / 'lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        source, video, choice = selected_wallpaper()
        st = source.stat()
        identity = {'output': str(OUTPUT), 'source': str(source), 'mtime': st.st_mtime_ns, 'size': st.st_size,
                    'choice': choice, 'sigma': args.sigma}
        fingerprint = hashlib.sha256(json.dumps(identity, sort_keys=True, default=str).encode()).hexdigest()
        state = CACHE / 'state.json'
        try:
            previous = json.loads(state.read_text())
        except (OSError, ValueError):
            previous = {}
        if not args.force and OUTPUT.is_file() and previous.get('fingerprint') == fingerprint:
            if previous.get('reload_pending'):
                reload_ghostty()
                state.write_text(json.dumps({'fingerprint': fingerprint}))
            return
        ffmpeg = shutil.which('ffmpeg', path=ENV['PATH'])
        if not ffmpeg:
            raise RuntimeError('找不到 ffmpeg；请先安装 brew install ffmpeg')
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        fd, tmp_name = tempfile.mkstemp(prefix='.wallpaper-', suffix='.png', dir=OUTPUT.parent)
        os.close(fd)
        tmp = Path(tmp_name)
        intermediate = None
        try:
            input_path = source
            if source.suffix.lower() in ('.heic', '.heif'):
                fd, name = tempfile.mkstemp(prefix='ghostty-wallpaper-', suffix='.png')
                os.close(fd)
                intermediate = Path(name)
                run(['/usr/bin/sips', '-s', 'format', 'png', str(source), '--out', str(intermediate)],
                    stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
                input_path = intermediate
            cmd = [ffmpeg, '-v', 'error', '-y']
            if video:
                cmd += ['-ss', '5']
            cmd += ['-i', str(input_path), '-frames:v', '1', '-vf',
                    f'gblur=sigma={args.sigma},format=rgb24', '-update', '1', str(tmp)]
            run(cmd, stderr=subprocess.PIPE)
            os.replace(tmp, OUTPUT)
        finally:
            tmp.unlink(missing_ok=True)
            if intermediate:
                intermediate.unlink(missing_ok=True)
        state.write_text(json.dumps({'fingerprint': fingerprint, 'reload_pending': True}))
        reload_ghostty()
        state.write_text(json.dumps({'fingerprint': fingerprint}))
        print(f'Ghostty 背景已更新：{source}')


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError, plistlib.InvalidFileException) as exc:
        print(f'Ghostty 壁纸同步失败：{exc}', file=sys.stderr)
        sys.exit(1)
