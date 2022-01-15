#!/bin/bash
#
#SPDX-License-Identifier: GPL-3.0-or-later
#myMPD (c) 2021-2022 Juergen Mang <mail@jcgames.de>
#https://github.com/jcorporation/radiodb

# simple testsuite

set -euo pipefail

# print out commands
[ -z "${DEBUG+x}" ] || set -x

echo "Branching test"
git checkout -b test

echo "Adding new webradio"
./build.sh add_radio_from_json test/new-webradio.json

file sources/mympd-webradios/http___test_radio_teststream.m3u
file sources/mympd-pics/http___test_radio_teststream.webp
IMAGE_CHK=$(md5sum sources/mympd-pics/http___test_radio_teststream.webp)

echo "Modify the new webradio"
./build.sh modify_radio_from_json test/modify-webradio.json

grep "\-modified" sources/mympd-webradios/http___test_radio_teststream.m3u > /dev/null
NEW_IMAGE_CHK=$(md5sum sources/mympd-pics/http___test_radio_teststream.webp)
[ "$IMAGE_CHK" = "$NEW_IMAGE_CHK" ] && false

echo "Change only the streamuri of the new webradio"
./build.sh modify_radio_from_json test/rename-webradio.json

[ -f sources/mympd-webradios/http___test_radio_teststream.m3u ] && false
[ -f sources/mympd-pics/http___test_radio_teststream.webp ] && false
file sources/mympd-webradios/http___test_radio_teststream-modified.m3u
file sources/mympd-pics/http___test_radio_teststream-modified.webp

echo "Delete the new webradio"
./build.sh delete_radio_from_json test/delete-webradio.json

[ -f sources/mympd-webradios/http___test_radio_teststream-modified.m3u ] && false
[ -f sources/mympd-pics/http___test_radio_teststream-modified.webp ] && false

echo "Check for changes"
[ "$(git diff | wc -l)" -gt 0 ] && false

echo "Create index"
./build.sh create

echo "Remove test branch"
git checkout master
git branch -D test

echo "All tests finished sucessfull"
exit 0
