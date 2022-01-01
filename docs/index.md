This is my attempt to create a curated webradio list for [myMPD](https://github.com/jcorporation/myMPD).

Contributions to the webradio database are very welcome. It should be a community driven database. You must only open an issue to add a webradio. Your proposal will be reviewed and then merged, therefore it could take some time before the webradio is added.

Currently there are <span id="stationCount"></span> stations in the list.

- [Browse the repository](https://github.com/jcorporation/webradiodb)
- [Get the json index file](https://jcorporation.github.io/webradiodb/db/index/webradios.min.json)
- [Get the js file](https://jcorporation.github.io/webradiodb/db/index/webradios.min.js)

## Add a webradio

- Open a [GitHub Issue](https://github.com/jcorporation/webradiodb/issues/new?template=add-webradio.yml)

## Simple station search

<input type="search" value="" id="searchstr" placeholder="Search by station name"/>
<hr/>
<div id="result">Type search string and press enter.</div>

<script src="db/index/webradios.min.js"></script>
<script src="assets/js/radiodb.js"></script>
