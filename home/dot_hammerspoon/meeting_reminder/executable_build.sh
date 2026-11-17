#!/bin/sh
# Builds MeetingEvents.app next to this script.
set -e
cd "$(dirname "$0")"
APP=MeetingEvents.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O MeetingEvents.swift -o "$APP/Contents/MacOS/MeetingEvents"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.hammerspoon.meetingevents</string>
  <key>CFBundleName</key><string>MeetingEvents</string>
  <key>CFBundleExecutable</key><string>MeetingEvents</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSUIElement</key><true/>
  <key>NSCalendarsFullAccessUsageDescription</key><string>Hammerspoon meeting reminders read upcoming events.</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo built "$PWD/$APP"
