# myMPD Webradio Database

[![createWebradioIndex](https://github.com/jcorporation/webradiodb/actions/workflows/createWebradioIndex.yml/badge.svg)](https://github.com/jcorporation/webradiodb/actions/workflows/createWebradioIndex.yml)
[![pages-build-deployment](https://github.com/jcorporation/webradiodb/actions/workflows/pages/pages-build-deployment/badge.svg)](https://github.com/jcorporation/webradiodb/actions/workflows/pages/pages-build-deployment)

This is my attempt to create a curated webradio list for [myMPD](https://github.com/jcorporation/myMPD).

- [Station search](https://jcorporation.github.io/webradiodb/)

Contributions to the webradio database are very welcome. It should be a community driven database. You must only open an issue to add a webradio. Your proposal will be reviewed and then merged, therefore it could take some time before the webradio is added.

## Adding new webradios

1. Simple: Open an [issue](https://github.com/jcorporation/webradiodb/issues/new?template=add-webradio.yml).
2. Advanced: Fork this repository - add/modify entries and create a pull request. You should only change the `mympd-*` folders.

## Usage

This project is designed as an easily integratable webradio database for music players. At the moment there is no api endpoint to query the database. An application should fetch the metadata json file and use it locally.

## Some internals

At the moment there are two sources for webradio files:

- Webradios from moode audio (sources/moode-*)
- Manually added files (sources/mympd-*)

Webradios are saved as extended m3u files with some custom fields. A coverimage could be specified as file in the pics folder or an url.

```
#EXTM3U
#EXTINF:-1,<name>
#EXTGENRE:<genre>
#PLAYLIST:<name>
#EXTIMG:<cover>
#HOMEPAGE:<homepage>
#COUNTRY:<country>
#LANGUAGE:<language>
#DESCRIPTION:<description>
<streamuri>
```

The filename of the playlist and the coverimage are derived from the streamuri by replacing `<>/.:?&$!#\|` characters with `_`. This is the same behaviour as in myMPD and makes this playlists compatible with the myMPD webradio feature.

You must not download the station images, instead you can prepend `https://jcorporation.github.io/webradiodb/publish/pics/` to the image name, e.g. https://jcorporation.github.io/webradiodb/publish/pics/http___119_15_96_188_stream2_mp3.webp.

The final files are located in the `publish` folder, it is rebuild on each push request.

- Playlists: [publish/webradios](/jcorporation/webradiodb/tree/master/publish/webradios)
- Station images: [publish/pics](/jcorporation/webradiodb/tree/master/publish/pics)
- Metadata as json and javascript: [publish/index](/jcorporation/webradiodb/tree/master/publish/index)

This repository is also published through [GitHub Pages](https://jcorporation.github.io/webradiodb/).

## Script usage

The script is used by GitHub actions.

Dependencies: csvkit, jq, wget, imagemagick

Type `./build.sh` for usage information.

## Copyright

Everyone is free to use the collected data in their works. I give all the rights I have at the accumulated data to the public domain.

2021-2022 Juergen Mang <mail@jcgames.de>
