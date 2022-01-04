const resultEl = document.getElementById('result');
const issueUri = 'https://github.com/jcorporation/webradiodb/issues/new';
const issueDelete = '?labels=DeleteWebradio&template=delete-webradio.yml';
const issueModify = '?labels=ModifyWebradio&template=modify-webradio.yml';
const searchInput = document.getElementById('searchStr');
const genreSelect = document.getElementById('genres');
const countrySelect = document.getElementById('countries');
const languageSelect = document.getElementById('languages');

document.getElementById('lastUpdate').textContent = new Date(webradios.timestamp * 1000).toLocaleString('en-US');
document.getElementById('stationCount').textContent = webradios.total;

function populateSelect(el, options) {
  for (const value of options) {
    const opt = document.createElement('option');
    opt.text = value;
    opt.value = value;
    el.appendChild(opt);
  }
}

populateSelect(genreSelect, webradioGenres);
populateSelect(countrySelect, webradioCountries);
populateSelect(languageSelect, webradioLanguages);

function getSelectValue(el) {
  return el.selectedIndex >= 0 ? el.options[el.selectedIndex].getAttribute('value') : '';
}

searchInput.addEventListener('keyup', function(event) {
  if (event.key === 'Enter') {
    search();
  }
}, false);

document.getElementById('searchBtn').addEventListener('click', function() {
  search();
}, false);

function search() {
  const searchstr = searchInput.value.toLowerCase();
  resultEl.textContent = '';
  if (searchstr.length < 3) {
    resultEl.innerText = 'Searchstring is too short.';
    return;
  }
  let i = 0;
  const genreFilter = getSelectValue(genreSelect);
  const countryFilter = getSelectValue(countrySelect);
  const languageFilter = getSelectValue(languageSelect);
  for (const key in webradios.data) {
    if (webradios.data[key].PLAYLIST.toLowerCase().indexOf(searchstr) > -1 &&
        (genreFilter === ''    || webradios.data[key].EXTGENRE.includes(genreFilter)) &&
        (countryFilter === ''  || countryFilter === webradios.data[key].COUNTRY) &&
        (languageFilter === '' || languageFilter === webradios.data[key].LANGUAGE)
    ) {
      i++;
      const div = document.createElement('div');
      const pic = webradios.data[key].EXTIMG.indexOf('http:') === 0 ||
          webradios.data[key].EXTIMG.indexOf('https:') === 0 ?
              webradios.data[key].EXTIMG : 'db/pics/' + webradios.data[key].EXTIMG;
      div.innerHTML =
          '<table>' +
            '<caption></caption>' +
            '<tbody>' +
              '<tr>' +
                '<td rowspan="6"><img src="" class="stationImage"/></td><td>Genre</td>' +
                '<td class="genre"></td></tr>' +
              '<tr><td>Country</td><td class="country"></td></tr>' +
              '<tr><td>Homepage</td><td><a class="homepage" target="_blank" href=""></a></td></tr>' +
              '<tr><td>Stream URI</td><td><input type="text" value=""/></td></tr>' +
              '<tr><td>Playlist</td><td><a class="playlist" target="_blank" href="">Get playlist</a></td></tr>' +
              '<tr><td colspan="2" class="description"></td></tr>' +
            '</tbody>' +
            '<tfoot>' +
              '<tr><td colspan="3">' +
                '<a class="modify" href="">Modify</a>&nbsp;&nbsp;<a class="delete" href="">Delete</a>' +
              '</td></tr>' +
            '</tfoot>' +
          '</table>';
      div.getElementsByTagName('caption')[0].textContent = webradios.data[key].PLAYLIST;
      div.getElementsByTagName('img')[0].src = pic;
      div.getElementsByClassName('genre')[0].textContent = webradios.data[key].EXTGENRE.join(', ');
      div.getElementsByClassName('country')[0].textContent = webradios.data[key].COUNTRY + ' / ' + webradios.data[key].LANGUAGE;
      div.getElementsByClassName('homepage')[0].href = webradios.data[key].HOMEPAGE;
      div.getElementsByClassName('homepage')[0].textContent = webradios.data[key].HOMEPAGE;
      div.getElementsByTagName('input')[0].value = webradios.data[key].streamUri;
      div.getElementsByClassName('playlist')[0].href = 'db/webradios/' + key;
      div.getElementsByClassName('description')[0].textContent = webradios.data[key].DESCRIPTION;

      div.getElementsByClassName('modify')[0].href =
        issueUri + issueModify + '&title=' + encodeURIComponent('[Modify Webradio]: ' + webradios.data[key].PLAYLIST) +
          '&modifyWebradio=' + encodeURIComponent(webradios.data[key].streamUri) +
          '&name=' + encodeURIComponent(webradios.data[key].PLAYLIST) +
          '&streamuri=' + encodeURIComponent(webradios.data[key].streamUri) +
          '&genre=' + encodeURIComponent(webradios.data[key].EXTGENRE) +
          '&homepage=' + encodeURIComponent(webradios.data[key].HOMEPAGE) +
          '&image=' + encodeURIComponent(webradios.data[key].EXTIMG) +
          '&country=' + encodeURIComponent(webradios.data[key].COUNTRY) +
          '&language=' + encodeURIComponent(webradios.data[key].LANGUAGE) +
          '&description=' + encodeURIComponent(webradios.data[key].DESCRIPTION);

      div.getElementsByClassName('delete')[0].href =
        issueUri + issueDelete + '&title=' + encodeURIComponent('[Delete Webradio]: ' + webradios.data[key].PLAYLIST) +
          '&deleteWebradio=' + encodeURIComponent(webradios.data[key].streamUri);
      resultEl.appendChild(div);
    }
  }
  if (i === 0) {
    resultEl.innerText = 'No search result.';
  }
}
