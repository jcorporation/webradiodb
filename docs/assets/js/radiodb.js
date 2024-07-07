"use strict";
// SPDX-License-Identifier: GPL-3.0-or-later
// myMPD (c) 2021-2022 Juergen Mang <mail@jcgames.de>
// https://github.com/jcorporation/mympd

const resultEl = document.getElementById('result');
const issueUri = 'https://github.com/jcorporation/webradiodb/issues/new';
const issueDelete = '?labels=DeleteWebradio&template=delete-webradio.yml';
const issueModify = '?labels=ModifyWebradio&template=modify-webradio.yml';
const issueNew = '?labels=AddWebradio&template=add-webradio.yml';
const issueAddAlternate = '?labels=AddAlternateStream&template=add-alternate-stream.yml';
const issueDeleteAlternate = '?labels=DeleteAlternateStream&template=delete-alternate-stream.yml';
const searchInput = document.getElementById('searchStr');
const genreSelect = document.getElementById('genres');
const countrySelect = document.getElementById('countries');
const regionSelect = document.getElementById('regions');
const languageSelect = document.getElementById('languages');
const codecSelect = document.getElementById('codecs');
const bitrateSelect = document.getElementById('bitrates');
const sortSelect = document.getElementById('sort');
const resultLimit = 25;

document.getElementById('lastUpdate').textContent = new Date(webradiodb.timestamp * 1000).toLocaleString('en-US');
document.getElementById('stationCount').textContent = webradiodb.totalWebradios;

function countStationsWithErrors() {
    let errors = 0;
    for (const key in webradiodb.webradioStatus) {
        if (webradiodb.webradios[key]) {
            errors++;
        }
    }
    return errors;
}

const errorCount = countStationsWithErrors();
if ( errorCount === 0) {
    document.getElementById('stationErrors').style.display = 'none';
}
else {
    document.getElementById('stationErrorCount').textContent = errorCount;
}

function appendOpt(el, value, text) {
    const opt = document.createElement('option');
    opt.text = text;
    opt.value = value;
    el.appendChild(opt);
}

function populateSelect(el, options) {
    for (const value of options) {
        appendOpt(el, value, value);
    }
}

function populateRegions() {
    regionSelect.options.length = 0;
    appendOpt(regionSelect, '', 'Region');
    const country = getSelectValue(countrySelect);
    if (country !== '') {
        populateSelect(regionSelect, webradiodb.webradioRegions[country]);
    }
}

populateSelect(genreSelect, webradiodb.webradioGenres);
populateSelect(countrySelect, webradiodb.webradioCountries);
populateSelect(languageSelect, webradiodb.webradioLanguages);
populateSelect(codecSelect, webradiodb.webradioCodecs);
populateSelect(bitrateSelect, webradiodb.webradioBitrates);

function getSelectValue(el) {
    return el.selectedIndex >= 0
        ? el.options[el.selectedIndex].getAttribute('value')
        : '';
}

searchInput.addEventListener('keyup', function(event) {
    if (event.key === 'Enter') {
        showSearchResult(0, resultLimit, false);
    }
}, false);

countrySelect.addEventListener('change', function() {
    populateRegions();
}, false);

document.getElementById('searchBtn').addEventListener('click', function() {
    showSearchResult(0, resultLimit, false);
}, false);

document.getElementById('searchErrorLink').addEventListener('click', function(event) {
    showSearchResult(0, 100, true);
    event.preventDefault();
}, false);

function uriHostname(uri) {
    return uri.replace(/^.+:\/\/([^/]+)\/.*$/, '$1');
}

function returnStreamError(m3u) {
    const p = document.createElement('p');
    p.classList.add('error');
    p.textContent = 'Last check (' + m3u.date + ', #' + m3u.count  + '): ' + m3u.error;
    return p;
}

function search(name, genre, country, region, language, codec, bitrate, sort, offset, limit, error) {
    name = name.toLowerCase();
    const obj = {
        "result": {
            "returnedEntities": 0,
            "totalEntities": 0,
            "data": []
        }
    };

    for (const key in webradiodb.webradios) {
        if (webradiodb.webradios[key].Name.toLowerCase().indexOf(name) > -1 &&
            (genre === ''    || webradiodb.webradios[key].Genre.includes(genre)) &&
            (country === ''  || country === webradiodb.webradios[key].Country) &&
            (region === ''   || region === webradiodb.webradios[key].Region) &&
            (language === '' || webradiodb.webradios[key].Languages.includes(language)) &&
            (codec === ''    || webradiodb.webradios[key].allCodecs.includes(codec)) &&
            (bitrate === 0   || bitrate <= webradiodb.webradios[key].highestBitrate)
        ) {
            if (error === true) {
                if (webradiodb.webradioStatus[key]) {
                    webradiodb.webradios[key].filename = key;
                    obj.result.data.push(webradiodb.webradios[key]);
                    obj.result.totalEntities++;
                }
            }
            else {
                webradiodb.webradios[key].filename = key;
                obj.result.data.push(webradiodb.webradios[key]);
                obj.result.totalEntities++;
            }
        }
    }
    obj.result.data.sort(function(a, b) {
        let lca;
        let lcb;
        if (typeof a === 'string') {
            lca = a[sort].toLowerCase();
            lcb = b[sort].toLowerCase();
        }
        else {
            lca = a[sort];
            lcb = b[sort];
        }
        //primary sort by defined tag
        if (lca < lcb) {
            return -1;
        }
        if (lca > lcb) {
            return 1;
        }
        //secondary sort by Name
        if (sort !== 'Name') {
            lca = a.Name.toLowerCase();
            lcb = b.Name.toLowerCase();
            if (lca < lcb) {
                return -1;
            }
            if (lca > lcb) {
                return 1;
            }
        }
        //equal
        return 0;
    });
    if (offset > 0) {
        obj.result.data.splice(0, offset - 1);
    }
    const last = obj.result.data.length - limit;
    if (last > 0) {
        obj.result.data.splice(limit, last);
    }
    obj.result.returnedEntities = obj.result.data.length;
    return obj;
}

function showSearchResult(offset, limit, error) {
    if (error === true) {
        searchInput.value = '';
        genreSelect.selectedIndex = 0;
        countrySelect.selectedIndex = 0;
        regionSelect.selectedIndex = 0;
        languageSelect.selectedIndex = 0;
        codecSelect.selectedIndex = 0;
        bitrateSelect.selectedIndex = 0;
        offset = 0;
        limit = 100;
    }
    const searchstr = searchInput.value.toLowerCase();
    const genreFilter = getSelectValue(genreSelect);
    const countryFilter = getSelectValue(countrySelect);
    const regionFilter = getSelectValue(regionSelect);
    const languageFilter = getSelectValue(languageSelect);
    const codecFilter = getSelectValue(codecSelect);
    const bitrateFilter = getSelectValue(bitrateSelect);
    const sort = getSelectValue(sortSelect);

    if (offset === 0) {
        resultEl.textContent = '';
    }

    const obj = search(searchstr, genreFilter, countryFilter, regionFilter, languageFilter, codecFilter, bitrateFilter, sort, offset, limit, error);
    document.getElementById('resultCount').textContent = obj.result.totalEntities;
    for (const key in obj.result.data) {
        const div = document.createElement('div');
        const pic = obj.result.data[key].Image.indexOf('http:') === 0 ||
            obj.result.data[key].Image.indexOf('https:') === 0 ?
                obj.result.data[key].Image : 'db/pics/' + obj.result.data[key].Image;
        div.innerHTML =
            '<table>' +
                '<caption></caption>' +
                '<tbody>' +
                    '<tr>' +
                        '<td rowspan="8"><img src="" class="stationImage"/></td><td>Genre</td>' +
                        '<td class="genre"></td>' +
                    '</tr>' +
                    '<tr><td>Country</td><td class="country"></td></tr>' +
                    '<tr><td>Language</td><td class="language"></td></tr>' +
                    '<tr><td>Homepage</td><td><a class="homepage" target="_blank" href=""></a></td></tr>' +
                    '<tr><td>Stream URI</td><td><input type="text" value=""/></td></tr>' +
                    '<tr><td>Playlist</td><td><a class="playlist" target="_blank" href="">Get playlist</a></td></tr>' +
                    '<tr><td>Format</td><td class="format"></td></tr>' +
                    '<tr><td>Alternate streams</td><td class="alternativeStreams"></td></tr>' +
                    '<tr><td colspan="3" class="description"></td></tr>' +
                '</tbody>' +
                '<tfoot>' +
                    '<tr>' +
                        '<td colspan="3">' +
                            '<a class="modify" href="">Modify</a>&nbsp;|&nbsp;<a class="delete" href="">Delete</a>&nbsp;|&nbsp;' +
                            '<a class="addAlternate" href="">Add alternate stream</a>'
                        '</td>' +
                    '</tr>' +
                '</tfoot>' +
            '</table>';
        div.getElementsByTagName('caption')[0].textContent = obj.result.data[key].Name;
        div.getElementsByTagName('img')[0].src = pic;
        div.getElementsByClassName('genre')[0].textContent = obj.result.data[key].Genre.join(', ');
        div.getElementsByClassName('country')[0].textContent = obj.result.data[key].Country +
            (obj.result.data[key].Region === ''
                ? ''
                : ' / ' + obj.result.data[key].Region);
        div.getElementsByClassName('language')[0].textContent = obj.result.data[key].Languages.join(', ');
        let format = obj.result.data[key].Codec;
        if (format !== '' && obj.result.data[key].Bitrate !== '') {
            format += ' / ';
        }
        if (obj.result.data[key].Bitrate !== 0) {
            format += obj.result.data[key].Bitrate + ' kbit'
        }
        if (format === '') {
            format = 'unknown';
        }
        div.getElementsByClassName('format')[0].textContent = format;
        div.getElementsByClassName('homepage')[0].href = obj.result.data[key].Homepage;
        div.getElementsByClassName('homepage')[0].textContent = uriHostname(obj.result.data[key].Homepage);
        div.getElementsByTagName('input')[0].value = obj.result.data[key].StreamUri;
        div.getElementsByClassName('playlist')[0].href = 'db/webradios/' + obj.result.data[key].filename;
        div.getElementsByClassName('description')[0].textContent =
            obj.result.data[key].Description !== '' ? obj.result.data[key].Description : 'No description available';
        let alternateCount = 0;
        for (const alternate in obj.result.data[key].alternativeStreams) {
            const p = document.createElement('p');
            const a = document.createElement('a');
            a.innerText = obj.result.data[key].alternativeStreams[alternate].Codec + ' / ' +
                obj.result.data[key].alternativeStreams[alternate].Bitrate + 'kbit';
            a.href = 'db/webradios/' + alternate + '.m3u';
            a.title = 'Download playlist';
            p.appendChild(a);
            const filename = obj.result.data[key].filename + '.' + obj.result.data[key].alternativeStreams[alternate].Codec + '.' +
                obj.result.data[key].alternativeStreams[alternate].Bitrate;
            const del = document.createElement('a');
            del.href = issueUri + issueDeleteAlternate + '&title=' + encodeURIComponent('[Delete alternate stream for webradio]: ' + obj.result.data[key].Name) +
                '&deleteAlternateStream=' + encodeURIComponent(filename);
            del.textContent = '(X)'
            del.title = 'Delete';
            del.classList.add('delAternateStream');
            p.appendChild(del);
            div.getElementsByClassName('alternativeStreams')[0].appendChild(p);
            if (webradiodb.webradioStatus[alternate + '.m3u'] !== undefined) {
                const error = returnStreamError(webradiodb.webradioStatus[alternate + '.m3u']);
                div.getElementsByClassName('alternativeStreams')[0].appendChild(error);
            }
            alternateCount++;
        }
        if (alternateCount === 0) {
            const p = document.createElement('p');
            p.textContent = 'No alternative streams';
            div.getElementsByClassName('alternativeStreams')[0].appendChild(p);
        }

        div.getElementsByClassName('modify')[0].href =
            issueUri + issueModify + '&title=' + encodeURIComponent('[Modify Webradio]: ' + obj.result.data[key].Name) +
                '&modifyWebradio=' + encodeURIComponent(obj.result.data[key].StreamUri) +
                '&name=' + encodeURIComponent(obj.result.data[key].Name) +
                '&streamuri=' + encodeURIComponent(obj.result.data[key].StreamUri) +
                '&genre=' + encodeURIComponent(obj.result.data[key].Genre.join(',')) +
                '&homepage=' + encodeURIComponent(obj.result.data[key].Homepage) +
                '&image=' + encodeURIComponent(obj.result.data[key].Image) +
                '&country=' + encodeURIComponent(obj.result.data[key].Country) +
                '&region=' + encodeURIComponent(obj.result.data[key].Region) +
                '&language=' + encodeURIComponent(obj.result.data[key].Language) +
                '&codec=' + encodeURIComponent(obj.result.data[key].Codec) +
                '&bitrate=' + encodeURIComponent(obj.result.data[key].Bitrate) +
                '&description=' + encodeURIComponent(obj.result.data[key].Description);

        div.getElementsByClassName('delete')[0].href =
            issueUri + issueDelete + '&title=' + encodeURIComponent('[Delete Webradio]: ' + obj.result.data[key].Name) +
                '&deleteWebradio=' + encodeURIComponent(obj.result.data[key].StreamUri);
        div.getElementsByClassName('addAlternate')[0].href =
            issueUri + issueAddAlternate + '&title=' + encodeURIComponent('[Add alternate stream for webradio]: ' + obj.result.data[key].Name) +
                '&modifyWebradio=' + encodeURIComponent(obj.result.data[key].StreamUri);

        if (webradiodb.webradioStatus[obj.result.data[key].filename] !== undefined) {
            const error = returnStreamError(webradiodb.webradioStatus[obj.result.data[key].filename]);
            div.getElementsByClassName('description')[0].appendChild(error);
        }

        resultEl.appendChild(div);
    }
    const last = offset + obj.result.returnedEntities;
    if (obj.result.totalEntities > last) {
        const a = document.createElement('a');
        a.setAttribute('id', 'more');
        a.setAttribute('href', '#');
        a.textContent = 'Show more results';
        a.addEventListener('click', function(event) {
            event.preventDefault();
            event.target.remove();
            showSearchResult(last + 1, limit, false);
        }, false);
        resultEl.appendChild(a);
    }
    else if (obj.result.returnedEntities === 0) {
        const div = document.createElement('div');
        div.classList.add('noResult');
        div.innerHTML = '<p>No search result.</p>' +
            '<p><a href="#">Add this webradio to the database</a></p>';
        div.getElementsByTagName('a')[0].href =
            issueUri + issueNew + '&title=' + encodeURIComponent('[Add Webradio]: ' + searchstr) +
                '&name=' + encodeURIComponent(searchstr);
        resultEl.appendChild(div);
    }
}
