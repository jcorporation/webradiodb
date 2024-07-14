---
layout: default
---

This is my attempt to create a curated webradio list for [myMPD](https://github.com/jcorporation/myMPD).

Contributions to the webradio database are very welcome. It should be a community driven database. You must only open an issue to add or modify a webradio. Your proposal will be reviewed and then merged, therefore it could take some time before the webradio is added. Please do not add geo-fenced streams.

Currently there are <span id="stationCount"></span> stations in the database and the last update was on <span id="lastUpdate"></span>.

<div id="stationErrors">
There are <span id="stationErrorCount"></span> not working stations in the database: <a id="searchErrorLink" href="#">Help fixing it</a>
</div>

### Add a webradio

- Open a [GitHub Issue](https://github.com/jcorporation/webradiodb/issues/new?labels=AddWebradio&template=add-webradio.yml&title=%5BAdd+Webradio%5D%3A+)

### Modify a webradio

Search for the webradio and click on the modify link to open a prefilled GitHub issue.

## Webradio search

<div class="searchBar">
    <div class="row">
        <input id="searchStr" type="text" placeholder="Search by station name"/>
        <input id="searchBtn" type="button" value="Search"/>
    </div>
    <div class="row">
        <select id="genres">
            <option value="">Genre</option>
        </select>
        <select id="countries">
            <option value="">Country</option>
        </select>
        <select id="regions">
            <option value="">Region</option>
        </select>
        <select id="languages">
            <option value="">Language</option>
        </select>
        <select id="codecs">
            <option value="">Codec</option>
        </select>
        <select id="bitrates">
            <option value="">Bitrate (min)</option>
        </select>
        <select id="sort">
            <option value="Name">Sort by name</option>
            <option value="Country">Sort by country</option>
            <option value="Language">Sort by language</option>
            <option value="Codec">Sort by codec</option>
            <option value="Bitrate">Sort by bitrate</option>
            <option value="Last-Modified">Sort by last modified</option>
            <option value="Added">Sort by added timestamp</option>
        </select>
        <div>
            <input id="sort_desc" type="checkbox" value="1"> <label for="sort_desc">Desc</label>
        </div>
    </div>
</div>
<div class="resultCountRow">
    <small>Results: <span id="resultCount">0</span></small>
</div>
<div id="result">Type search string and press enter.</div>

<script src="db/index/webradiodb-combined.min.js"></script>
<script src="assets/js/radiodb.js"></script>
