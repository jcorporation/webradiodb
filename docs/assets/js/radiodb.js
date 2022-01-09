"use strict";
// SPDX-License-Identifier: GPL-3.0-or-later
// myMPD (c) 2021-2022 Juergen Mang <mail@jcgames.de>
// https://github.com/jcorporation/mympd

const resultEl = document.getElementById('result');
const issueUri = 'https://github.com/jcorporation/webradiodb/issues/new';
const issueDelete = '?labels=DeleteWebradio&template=delete-webradio.yml';
const issueModify = '?labels=ModifyWebradio&template=modify-webradio.yml';
const issueNew = '?labels=labels=AddWebradio&template=add-webradio.yml';
const searchInput = document.getElementById('searchStr');
const genreSelect = document.getElementById('genres');
const countrySelect = document.getElementById('countries');
const languageSelect = document.getElementById('languages');
const sortSelect = document.getElementById('sort');
const resultLimit = 25;

document.getElementById('lastUpdate').textContent = new Date(webradiodb.timestamp * 1000).toLocaleString('en-US');
document.getElementById('stationCount').textContent = webradiodb.totalWebradios;

function populateSelect(el, options) {
	for (const value of options) {
		const opt = document.createElement('option');
		opt.text = value;
		opt.value = value;
		el.appendChild(opt);
	}
}

populateSelect(genreSelect, webradiodb.webradioGenres);
populateSelect(countrySelect, webradiodb.webradioCountries);
populateSelect(languageSelect, webradiodb.webradioLanguages);

function getSelectValue(el) {
	return el.selectedIndex >= 0 ? el.options[el.selectedIndex].getAttribute('value') : '';
}

searchInput.addEventListener('keyup', function(event) {
	if (event.key === 'Enter') {
		showSearchResult(0, resultLimit);
	}
}, false);

document.getElementById('searchBtn').addEventListener('click', function() {
	showSearchResult(0, resultLimit);
}, false);

function uriHostname(uri) {
	return uri.replace(/^.+:\/\/([^/]+)\/.*$/, '$1');
}

function search(name, genre, country, language, sort) {
	const result = {
		"returnedEntities": 0,
		"data": []
	};

	for (const key of webradiodb.webradios) {
		if (webradiodb.webradios[key].Name.toLowerCase().indexOf(name) > -1 &&
			(genre === ''    || webradiodb.webradios[key].Genre.includes(genre)) &&
			(country === ''  || country === webradiodb.webradios[key].Country) &&
			(language === '' || language === webradiodb.webradios[key].Language)
		) {
			result.data.push(webradiodb.webradios[key]);
			result.returnedEntities++;
		}
	}
	result.data.sort(function(a, b) {
		if (a[sort] < b[sort]) {
			return -1;
		}
		if (a[sort] > b[sort]) {
			return 1;
		}
		return 0;
	});
	return result;
}

function showSearchResult(offset, limit) {
	const searchstr = searchInput.value.toLowerCase();
	const genreFilter = getSelectValue(genreSelect);
	const countryFilter = getSelectValue(countrySelect);
	const languageFilter = getSelectValue(languageSelect);
	const sort = getSelectValue(sortSelect);

	if (offset === 0) {
		resultEl.textContent = '';
	}

	const result = search(searchstr, genreFilter, countryFilter, languageFilter, sort);
	document.getElementById('resultCount').textContent = result.returnedEntities;
	let i = 0;
	const last = offset + limit;
	for (const key of result.data) {
		if (i < offset) {
			i++;
			continue;
		}
		if (i >= last) {
			const a = document.createElement('a');
			a.setAttribute('id', 'more');
			a.setAttribute('href', '#');
			a.textContent = 'Show more results';
			a.addEventListener('click', function(event) {
				event.preventDefault();
				event.target.remove();
				showSearchResult(last, limit);
			}, false);
			resultEl.appendChild(a);
			break;
		}
		i++;
		const div = document.createElement('div');
		const pic = result.data[key].Image.indexOf('http:') === 0 ||
			result.data[key].Image.indexOf('https:') === 0 ?
				result.data[key].Image : 'db/pics/' + result.data[key].Image;
		div.innerHTML =
			'<table>' +
				'<caption></caption>' +
				'<tbody>' +
					'<tr>' +
						'<td rowspan="6"><img src="" class="stationImage"/></td><td>Genre</td>' +
						'<td class="genre"></td>' +
					'</tr>' +
					'<tr><td>Country</td><td class="country"></td></tr>' +
					'<tr><td>Homepage</td><td><a class="homepage" target="_blank" href=""></a></td></tr>' +
					'<tr><td>Stream URI</td><td><input type="text" value=""/></td></tr>' +
					'<tr><td>Playlist</td><td><a class="playlist" target="_blank" href="">Get playlist</a></td></tr>' +
					'<tr><td colspan="2" class="description"></td></tr>' +
				'</tbody>' +
				'<tfoot>' +
					'<tr>' +
						'<td colspan="3">' +
							'<a class="modify" href="">Modify</a>&nbsp;&nbsp;<a class="delete" href="">Delete</a>' +
						'</td>' +
					'</tr>' +
				'</tfoot>' +
			'</table>';
		div.getElementsByTagName('caption')[0].textContent = result.data[key].Name;
		div.getElementsByTagName('img')[0].src = pic;
		div.getElementsByClassName('genre')[0].textContent = result.data[key].Genre.join(', ');
		div.getElementsByClassName('country')[0].textContent = result.data[key].Country + ' / ' + result.data[key].Language;
		div.getElementsByClassName('homepage')[0].href = result.data[key].Homepage;
		div.getElementsByClassName('homepage')[0].textContent = uriHostname(result.data[key].Homepage);
		div.getElementsByTagName('input')[0].value = result.data[key].StreamUri;
		div.getElementsByClassName('playlist')[0].href = 'db/webradios/' + key;
		div.getElementsByClassName('description')[0].textContent =
			result.data[key].Description !== '' ? result.data[key].Description : 'No description available';

		div.getElementsByClassName('modify')[0].href =
			issueUri + issueModify + '&title=' + encodeURIComponent('[Modify Webradio]: ' + result.data[key].Name) +
				'&modifyWebradio=' + encodeURIComponent(result.data[key].StreamUri) +
				'&name=' + encodeURIComponent(result.data[key].Name) +
				'&streamuri=' + encodeURIComponent(result.data[key].StreamUri) +
				'&genre=' + encodeURIComponent(result.data[key].Genre) +
				'&homepage=' + encodeURIComponent(result.data[key].Homepage) +
				'&image=' + encodeURIComponent(result.data[key].Image) +
				'&country=' + encodeURIComponent(result.data[key].Country) +
				'&language=' + encodeURIComponent(result.data[key].Language) +
				'&description=' + encodeURIComponent(result.data[key].Description);

		div.getElementsByClassName('delete')[0].href =
			issueUri + issueDelete + '&title=' + encodeURIComponent('[Delete Webradio]: ' + result.data[key].Name) +
				'&deleteWebradio=' + encodeURIComponent(result.data[key].StreamUri);
		resultEl.appendChild(div);
	}
	if (result.returnedEntities === 0) {
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
