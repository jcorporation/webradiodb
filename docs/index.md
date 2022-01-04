This is my attempt to create a curated webradio list for [myMPD](https://github.com/jcorporation/myMPD).

Contributions to the webradio database are very welcome. It should be a community driven database. You must only open an issue to add or modify a webradio. Your proposal will be reviewed and then merged, therefore it could take some time before the webradio is added.

Currently there are <span id="stationCount"></span> stations in the list and the last update was on <span id="lastUpdate"></span>.

### Add a webradio

- Open a [GitHub Issue](https://github.com/jcorporation/webradiodb/issues/new?template=add-webradio.yml)

### Modify a webradio

Search for the webradio and click on the modify link to open a prefilled GitHub issue.

## Webradio search

<div class="searchbar">
    <input id="searchStr" type="search" placeholder="Search by station name"/>
    <select id="genres">
        <option value="">Genre</option>
    </select>
    <select id="countries">
        <option value="">Country</option>
    </select>
    <select id="languages">
        <option value="">Language</option>
    </select>
    <select id="sort">
        <option value="PLAYLIST">Sort by name</option>
        <option value="EXTGENRE">Sort by genre</option>
        <option value="COUNTRY">Sort by country</option>
        <option value="LANGUAGE">Sort by language</option>
    </select>
    <input id="searchBtn" type="button" value="Search"/>
</div>
<hr/>
<div id="result">Type search string and press enter.</div>

<script src="db/index/webradiodb.min.js"></script>
<script src="assets/js/radiodb.js"></script>
