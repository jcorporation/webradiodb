# myMPD radio db

This is my attempt to create a curated webradio list for [myMPD](https://github.com/jcorporation/myMPD).

At the moment there are two sources for webradio files:
- Webradios from moode audio (sources/moode-*)
- Manually added files (sources/mympd-*)

## Adding new webradios

1. Fork this repository - create a new entry and a pull request
2. Open an issue with all needed data

## Usage in myMPD

1. Copy the m3u files from the `webradios` directory to `/var/lib/mympd/webradios`
2. Copy the webp files from the `pics` directory to `/var/lib/mympd/pics`
3. myMPD should show the webradios in the webradio favorites view

## Script usage

Dependencies: csvkit, wget, convert

- `./build.sh add_radio`: add a webradio
- `./build.sh create`: refresh the unfied directories
- `./build.sh sync_moode`: mirror the webradios from moode audio

## Copyright

Everyone is free to use the collected data (station names, etc.) in their works. I give all the rights I have at the accumulated data to the public domain.

2021 Juergen Mang <mail@jcgames.de>
