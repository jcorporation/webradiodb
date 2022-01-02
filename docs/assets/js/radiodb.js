const resultEl = document.getElementById('result');
document.getElementById('stationCount').textContent = Object.keys(webradios).length;

const issueUri = 'https://github.com/jcorporation/webradiodb/issues/new';
const issueDelete = '?labels=DeleteWebradio&template=delete-webradio.yml';
const issueModify = '?labels=ModifyWebradio&template=modify-webradio.yml';

document.getElementById('searchstr').addEventListener('keyup', function(event) {
  if (event.key === 'Enter') {
    const searchstr = event.target.value.toLowerCase();
    resultEl.textContent = '';
    if (searchstr.length < 3) {
      resultEl.innerText = 'Searchstring is too short.';
      return;
    }
    let i = 0;
    for (const key in webradios) {
      if (webradios[key].PLAYLIST.toLowerCase().indexOf(searchstr) > -1) {
        i++;
        const div = document.createElement('div');
        const pic = webradios[key].EXTIMG.indexOf('http:') === 0 ||
            webradios[key].EXTIMG.indexOf('https:') === 0 ?
                webradios[key].EXTIMG : 'db/pics/' + webradios[key].EXTIMG;
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
        div.getElementsByTagName('caption')[0] = webradios[key].PLAYLIST;
        div.getElementsByTagName('img')[0].src = pic;
        div.getElementsByClassName('genre')[0].textContent = webradios[key].EXTGENRE;
        div.getElementsByClassName('country')[0].textContent = webradios[key].COUNTRY + ' / ' + webradios[key].LANGUAGE;
        div.getElementsByClassName('homepage')[0].href = webradios[key].HOMEPAGE;
        div.getElementsByClassName('homepage')[0].textContent = webradios[key].HOMEPAGE;
        div.getElementsByTagName('input')[0].value = webradios[key].streamUri;
        div.getElementsByClassName('playlist')[0].href = 'db/webradios/' + key;
        div.getElementsByClassName('description')[0].textContent = webradios[key].DESCRIPTION;

        div.getElementsByClassName('modify')[0].href =
          issueUri + issueDelete + '&title=' + encodeURIComponent('[Modify Webradio]: ' + webradios[key].PLAYLIST) +
            '&modifyWebradio=' + encodeURIComponent(webradios[key].streamUri) +
            '&name=' + encodeURIComponent(webradios[key].PLAYLIST) +
            '&streamuri=' + encodeURIComponent(webradios[key].streamUri) +
            '&genre=' + encodeURIComponent(webradios[key].EXTGENRE) +
            '&homepage=' + encodeURIComponent(webradios[key].HOMEPAGE) +
            '&image=' + encodeURIComponent(webradios[key].EXTIMG) +
            '&country=' + encodeURIComponent(webradios[key].COUNTRY) +
            '&language=' + encodeURIComponent(webradios[key].LANGUAGE) +
            '&description=' + encodeURIComponent(webradios[key].DESCRIPTION);

        div.getElementsByClassName('delete')[0].href =
          issueUri + issueDelete + '&title=' + encodeURIComponent('[Delete Webradio]: ' + webradios[key].PLAYLIST) +
            '&deleteWebradio=' + encodeURIComponent(webradios[key].streamUri);
        resultEl.appendChild(div);
      }
    }
    if (i === 0) {
      resultEl.innerText = 'No search result.';
    }
  }
}, false);
