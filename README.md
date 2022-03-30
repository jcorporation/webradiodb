# myMPD Webradio Database

[![test](https://github.com/jcorporation/webradiodb/actions/workflows/test.yml/badge.svg)](https://github.com/jcorporation/webradiodb/actions/workflows/test.yml)
[![dbChecks](https://github.com/jcorporation/webradiodb/actions/workflows/dbChecks.yml/badge.svg)](https://github.com/jcorporation/webradiodb/actions/workflows/dbChecks.yml)
[![createWebradioIndex](https://github.com/jcorporation/webradiodb/actions/workflows/createWebradioIndex.yml/badge.svg)](https://github.com/jcorporation/webradiodb/actions/workflows/createWebradioIndex.yml)
[![pages-build-deployment](https://github.com/jcorporation/webradiodb/actions/workflows/pages/pages-build-deployment/badge.svg)](https://github.com/jcorporation/webradiodb/actions/workflows/pages/pages-build-deployment)

This is my attempt to create a curated webradio list for [myMPD](https://github.com/jcorporation/myMPD).

- [Station search](https://jcorporation.github.io/webradiodb/)

Contributions to the webradio database are very welcome. It should be a community driven database. You must only open an issue to add or modify a webradio. Your proposal will be reviewed and then merged, therefore it could take some time before the webradio is added.

## Add a new webradio

Open an [issue](https://github.com/jcorporation/webradiodb/issues/new?template=add-webradio.yml).

## Modify a webradio

[Search](https://jcorporation.github.io/webradiodb/) for the webradio and click on the modify link to open a prefilled GitHub issue.

## Usage

This project is designed as an easily integratable webradio database for music players. At the moment there is no api endpoint to query the database. An application should fetch the metadata json file and use it locally.

## Some internals

At the moment there are two sources for webradio files:

- Webradios from moode audio (sources/moode-*)
- Manually added files (sources/mympd-*)

### Workflows

#### Add, modify and delete a webradio
The primary workflow to add or modify a webradio is to open an issue. The issue must be manually approved by adding a merge label. A GitHub action is triggered on the label event and the build script runs:

- creates the m3u file
- downloads the image
- converts the image to webp and resizes it to 400x400 pixel

#### Index creation

The create workflow runs once a day. 

- copies files from `sources` to `docs/db` folder
- parses the m3u files and creates JSON index files

After this workflow the `docs` folder is published to the GitHub page.

### Storage format

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

The filename of the playlist and the coverimage are derived from the streamuri by replacing `<>/.:?&$!#\|;=` characters with `_`. This is the same behaviour as in myMPD and makes this playlists compatible with the myMPD webradio feature.

You must not download the station images, instead you can prepend `https://jcorporation.github.io/webradiodb/db/pics/` to the image name, e.g. https://jcorporation.github.io/webradiodb/db/pics/http___119_15_96_188_stream2_mp3.webp.

The final files are located in the `docs/db` folder, it is rebuild on each push request. The folder `docs` is published through [GitHub Pages](https://jcorporation.github.io/webradiodb/).

| FOLDER | DESCRIPTION |
| ------ | ----------- |
| [docs/db/webradios](docs/db/webradios) | Playlists |
| [docs/db/pics](docs/db/pics) | Station images |
| [docs/db/index](docs/db/index) | Metadata as json and javascript |

### Index files

| FILE | DESCRIPTION |
| ---- | ----------- |
| [countries.min.json](https://jcorporation.github.io/webradiodb/db/index/countries.min.json) | Array of countries |
| [genres.min.json](https://jcorporation.github.io/webradiodb/db/index/genres.min.json) | Array of genres |
| [languages.min.json](https://jcorporation.github.io/webradiodb/db/index/languages.min.json) | Array of languages |
| [webradios.min.json](https://jcorporation.github.io/webradiodb/db/index/webradios.min.json) | JSON object of webradios |
| [webradiodb-combined.min.json](https://jcorporation.github.io/webradiodb/db/index/webradiodb-combined.min.json) | JSON object file with all the above indexes |
| [webradiodb-combined.min.js](https://jcorporation.github.io/webradiodb/db/index/webradiodb-combined.min.js) | JavaScript file with all the above indexes |

The m3u fields are mapped for better readability.

| M3U FIELD | JSON KEY |
| --------- | -------- |
| EXTGENRE | Genre |
| PLAYLIST | Name |
| EXTIMG | Image |
| HOMEPAGE | Homepage |
| COUNTRY | Country |
| LANGUAGE | Language |
| DESCRIPTION | Description |
| uri | StreamUri |

```
"https___liveradio_swr_de_sw331ch_swr1bw_play_mp3.m3u": {
    "Genre": [
        "Pop",
        "Rock"
    ],
    "Name": "SWR 1",
    "Image": "https___liveradio_swr_de_sw331ch_swr1bw_play_mp3.webp",
    "Homepage": "https://www.swr.de/swr1/",
    "Country": "Germany",
    "Language": "German",
    "Description": "SWR 1 Baden-Wuerttemberg",
    "StreamUri": "https://liveradio.swr.de/sw331ch/swr1bw/play.mp3"
}
```

### Script usage

The script is used by GitHub actions.

Dependencies: imagemagick, jq, csvkit, curl

Type `./build.sh` for usage information.

## Copyright

Everyone is free to use the collected data in their works. I give all the rights I have at the accumulated data to the public domain.

2021-2022 Juergen Mang <mail@jcgames.de>
