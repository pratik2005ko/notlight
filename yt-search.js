const yt = require('youtube-search-api');
(async () => {
  const q = process.argv[2];
  if (!q) { console.log('[]'); return; }
  const r = await yt.GetListByKeyword(q, false, 8);
  const items = (r.items || []).filter(i => i.type === 'video').map(i => ({
    id: i.id, title: i.title, author: i.channelTitle, duration: i.length?.simpleText || ''
  }));
  console.log(JSON.stringify(items));
})().catch(() => console.log('[]'));
