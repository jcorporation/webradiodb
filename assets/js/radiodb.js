const resultEl = document.getElementById('result');
document.getElementById('stationCount').textContent = Object.keys(webradios).length;

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
                webradios[key].EXTIMG : 'publish/pics/' + webradios[key].EXTIMG;
        div.innerHTML =
            '<table>' +
                '<caption>' + webradios[key].PLAYLIST + '</caption>' +
                '<tbody>' +
                '<tr><td rowspan="4"><img src="' + pic + '" class="stationImage"/></td><td>Genre</td><td>' + webradios[key].EXTGENRE + '</td></tr>' +
                '<tr><td>Country</td><td>' + webradios[key].COUNTRY + '/' + webradios[key].LANGUAGE + '</td></tr>' +
                '<tr><td>Homepage</td><td><a target="_blank" href="' + webradios[key].HOMEPAGE + '">' + webradios[key].HOMEPAGE + '</a></td></tr>' +
                '<tr><td>Playlist</td><td><a target="_blank" href="publish/webradios/' + key + '">Get playlist</a></td></tr>' +
                '</tbody>' +
            '</table>';
        resultEl.appendChild(div);
      }
    }
    if (i === 0) {
      resultEl.innerText = 'No search result.';
    }
  }
}, false);
