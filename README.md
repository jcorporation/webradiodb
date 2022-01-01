# myMPD Webradio Database

This is my attempt to create a curated webradio list for [myMPD](https://github.com/jcorporation/myMPD).

At the moment there are two sources for webradio files:
- Webradios from moode audio (sources/moode-*)
- Manually added files (sources/mympd-*)

Webradios are saved as plain extended m3u files with some custom fields. A coverimage could be specified as file in the pics directory or an url.

```
#EXTM3U
#EXTINF:-1,<name>
#EXTGENRE:<genre>
#PLAYLIST:<name>
#EXTIMG:<cover>
#HOMEPAGE:<homepage>
#COUNTRY:<country>
#LANGUAGE:<language>
<streamuri>
```

The filename of the playlist and the coverimage are derived from the streamuri by replacing `<>/.:?&$!#\|` characters with `_`. This is the same behaviour as in myMPD and makes this playlists compatible with the myMPD webradio feature.

You can find the playlists in the `publish/webradios` directory and the station images in the `publish/pics` directory. There is also a json index file in the `publish/index` directory.

The publish directory is refreshed on each pull request through GitHub actions.

This repository is also published through [GitHub Pages](https://jcorporation.github.io/webradiodb/).

You must not download all the images, instead you can prepend `https://jcorporation.github.io/webradiodb/publish/pics/` to the image name, e.g. https://jcorporation.github.io/webradiodb/publish/pics/http___119_15_96_188_stream2_mp3.webp.

## Adding new webradios

1. Fork this repository - add/modify entries and create a pull request. You should only change the `mympd-*` folders, the `moode-*` folder are overwritten through the sync_moode action.
2. Open an [issue](https://github.com/jcorporation/webradiodb/issues/new?template=add-webradio.yml)

## Usage in myMPD

1. Copy the m3u files from the `publish/webradios` directory to `/var/lib/mympd/webradios`
2. Copy the webp files from the `publish/pics` directory to `/var/lib/mympd/pics`
3. myMPD should show the webradios in the webradio favorites view

## Script usage

Dependencies: csvkit, jq, wget, convert

- `./build.sh add_radio`: interactively adds an webradio to sources/mympd-webradios
- `./build.sh create`: copies pls and images from sources dir and creates an unified index
- `./build.sh sync_moode`: syncs the moode audio webradios to sources/moode-webradios, downloads and converts the images to webp

## Copyright

Everyone is free to use the collected data (station names, etc.) in their works. I give all the rights I have at the accumulated data to the public domain.

2021-2022 Juergen Mang <mail@jcgames.de>
