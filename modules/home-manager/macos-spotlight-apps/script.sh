#!/usr/bin/env bash

create_launcher() {
	printf '#!/bin/bash\nopen "%s"\n' "$1"
}

# Emit a minimal Info.plist for a wrapper app.
# Args: bundle_id exe_name display_name icon_file
create_info_plist() {
	cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>$2</string>
	<key>CFBundleIdentifier</key><string>$1</string>
	<key>CFBundleName</key><string>$3</string>
	<key>CFBundleDisplayName</key><string>$3</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleIconFile</key><string>$4</string>
</dict>
</plist>
EOF
}

src="$1"
dst="$2"

if [[ $dst != "$HOME/Applications/"* ]]; then
	echo "Error: target must be under ~/Applications/" >&2
	exit 1
fi

mkdir -p "$dst"
find "$dst" -maxdepth 1 -name "*.app" -type d -exec rm -rf {} +

# Create wrappers for each .app
for app in "$src"/*.app; do
	[ -e "$app" ] || continue

	# Resolve symlink to get actual app path
	app_source=$(readlink -f "$app")
	app_name=$(basename "$app_source")
	wrapper="$dst/$app_name"

	# Create wrapper structure
	mkdir -p "$wrapper/Contents/MacOS"
	mkdir -p "$wrapper/Contents/Resources"

	# Copy icons
	if [ -d "$app_source/Contents/Resources" ]; then
		find "$app_source/Contents/Resources" -maxdepth 1 -name "*.icns" \
			-exec cp {} "$wrapper/Contents/Resources/" \;
	fi

	# Read the original bundle id and icon, but write our OWN minimal
	# Info.plist rather than copying the app's verbatim. Two reasons:
	#   1. Reusing the real CFBundleIdentifier makes the wrapper collide
	#      with the /nix/store copy; Launch Services dedupes to the store
	#      path, which it refuses to launch from Spotlight ("...does not
	#      have permission to open (null)"). A unique id avoids this.
	#   2. Some apps (e.g. kitty) declare document/scheme handlers and
	#      LSRequiresNativeExecution; carried into an unsigned wrapper these
	#      make Launch Services reject the launch with error -54 (permErr).
	# A minimal plist with a distinct id sidesteps both.
	src_plist="$app_source/Contents/Info.plist"
	exe_name=$(basename "$app_source" .app)
	bundle_id=""
	icon_file=""
	if [ -f "$src_plist" ]; then
		bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" \
			"$src_plist" 2>/dev/null || true)
		icon_file=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" \
			"$src_plist" 2>/dev/null || true)
	fi
	[ -n "$bundle_id" ] || bundle_id="org.nixos.spotlight-wrapper.$exe_name"

	create_info_plist \
		"${bundle_id}.spotlight-wrapper" \
		"$exe_name" \
		"$exe_name" \
		"$icon_file" \
		>"$wrapper/Contents/Info.plist"

	# Create launcher script that opens the real app
	create_launcher "$app_source" >"$wrapper/Contents/MacOS/$exe_name"
	chmod +x "$wrapper/Contents/MacOS/$exe_name"
done
