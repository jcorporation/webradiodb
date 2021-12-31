---
layout: page
permalink: /
title: myMPD Webradio Database
---

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
      return;
    }
    for (const key in webradios) {
      if (webradios[key].PLAYLIST.toLowerCase().indexOf(searchstr) > -1) {
        const p = document.createElement('p');
        p.textContent = webradios[key].PLAYLIST;
        resultEl.appendChild(p);
      }
    }
  }
}, false);
</script>
