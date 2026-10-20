#!/usr/bin/env bash
set -euo pipefail
mkdir -p smoke
apk=$(find dist -name '*-x86_64.apk' -print -quit)
test -n "$apk"
adb install -r "$apk"
adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER dev.zeitlind.reader | tee smoke/launcher.txt
grep -q 'dev.zeitlind.reader/.MainActivity\|dev.zeitlind.reader/dev.zeitlind.reader.MainActivity' smoke/launcher.txt
adb logcat -c
adb shell am start -W -n dev.zeitlind.reader/.MainActivity | tee smoke/start.txt
grep -q 'Status: ok' smoke/start.txt
sleep 15
process_id=$(adb shell pidof dev.zeitlind.reader | tr -d '\r')
test -n "$process_id"
adb shell dumpsys package dev.zeitlind.reader > smoke/package.txt
grep -q android.intent.category.LAUNCHER smoke/package.txt
adb exec-out screencap -p > smoke/home.png
adb shell am start -W -a android.intent.action.VIEW -d 'zeitlind://sources?url=https%3A%2F%2Fcdn.jsdelivr.net%2Fgh%2Fkuiti%2Fmanga-source-index%40main%2F05-venera-sources%2Ftier1%2Findex.json' dev.zeitlind.reader | tee smoke/source-link.txt
sleep 4
adb exec-out screencap -p > smoke/source-import.png
adb logcat -d --pid="$process_id" > smoke/application-log.txt
if grep -q 'FATAL EXCEPTION' smoke/application-log.txt; then
  exit 1
fi
