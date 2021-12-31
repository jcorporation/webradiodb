This is my attempt to create a curated webradio list for [myMPD](https://github.com/jcorporation/myMPD).

- [Browse the repository](https://github.com/jcorporation/radiodb)
- [Get the json index file](https://jcorporation.github.io/radiodb/publish/index/webradios.min.json)
- [Get the js file](https://jcorporation.github.io/radiodb/publish/index/webradios.min.js)

## Simple station search

<input type="search" value="" id="searchstr"/>
<hr/>
<div id="result">Type search string and press enter.</div>

<script src="publish/index/webradios.min.js"></script>
<script>
  const resultEl = document.getElementById('result');
  document.getElementById('searchstr').addEventListener('keyup', function(event) {
    if (event.key === 'Enter') {
      const searchstr = event.target.value.toLowerCase();
      resultEl.textContent = '';
      if (searchstr.length < 3) {
        resultEl.innerText = 'Searchstring to short.';
        return;
      }
      let i = 0;
      for (const key in webradios) {
        if (webradios[key].PLAYLIST.toLowerCase().indexOf(searchstr) > -1) {
          i++;
          const div = document.createElement('div');
          div.style.width = "100%";
          div.style.minHeight = "5rem";
          const pic = webradios[key].EXTIMG.indexOf('http:') === 0 ||
              webradios[key].EXTIMG.indexOf('https:') === 0 ?
                  webradios[key].EXTIMG : 'publish/pics/' + webradios[key].EXTIMG;
          div.innerHTML =
            '<img src="' + pic + '" style="float:left;display:block;width:5rem;height:auto;margin-right:2rem;"/>' +
            '<div>' + 
              '<h3>' + webradios[key].PLAYLIST + '</h3>' +
              '<p><a target="_blank" href="publish/webradios/' + key + '">Get playlist</a></p>' +
            '</div>';
          resultEl.appendChild(div);
        }
      }
      if (i === 0) {
        resultEl.innerText = 'No search result.';
      }
    }
  }, false);
</script>
