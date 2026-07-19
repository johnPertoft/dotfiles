#!/bin/sh
# extract — universal unarchiver.
#
# Uses bsdtar (libarchive), which auto-detects tar, gz, bz2, xz, zst, lz4,
# zip, 7z, cpio, ar, iso and more from a single tool — no per-format case.
# Each argument is extracted into its own directory (named after the archive,
# minus its extension) to avoid tarbombs scattering files into $PWD.

set -eu

usage() {
	echo "usage: extract <archive> [archive...]" >&2
	echo "  Extracts each archive into ./<name>/ (auto-detects format via bsdtar)." >&2
}

if [ "$#" -eq 0 ]; then
	usage
	exit 1
fi

case "$1" in
-h | --help)
	usage
	exit 0
	;;
esac

status=0

for archive in "$@"; do
	if [ ! -f "$archive" ]; then
		echo "extract: '$archive' is not a file" >&2
		status=1
		continue
	fi

	# Strip the directory and a trailing archive extension to name the output dir.
	# Handles single (.zip) and common double (.tar.gz) extensions.
	base=$(basename -- "$archive")
	case "$base" in
	*.tar.gz | *.tar.bz2 | *.tar.xz | *.tar.zst | *.tar.lz4 | *.tar.lz | *.tar.Z)
		dest=${base%.tar.*}
		;;
	*.tgz | *.tbz | *.tbz2 | *.txz | *.tzst)
		dest=${base%.*}
		;;
	*.*)
		dest=${base%.*}
		;;
	*)
		dest="${base}.extracted"
		;;
	esac

	if [ -e "$dest" ]; then
		echo "extract: '$dest' already exists, skipping '$archive'" >&2
		status=1
		continue
	fi

	echo "extract: '$archive' -> '$dest/'" >&2
	mkdir -p -- "$dest"
	if bsdtar -x -f "$archive" -C "$dest"; then
		# If the archive contained a single top-level dir with the same name,
		# flatten it so we don't end up with foo/foo/…
		inner=$(find "$dest" -mindepth 1 -maxdepth 1)
		count=$(printf '%s\n' "$inner" | grep -c .)
		if [ "$count" -eq 1 ] && [ -d "$inner" ] && [ "$(basename -- "$inner")" = "$dest" ]; then
			tmp="${dest}.__flatten__"
			mv -- "$inner" "$tmp"
			rmdir -- "$dest"
			mv -- "$tmp" "$dest"
		fi
	else
		echo "extract: failed to extract '$archive'" >&2
		rmdir -- "$dest" 2>/dev/null || true
		status=1
	fi
done

exit "$status"
