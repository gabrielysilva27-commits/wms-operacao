import {access,readFile,readdir} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
const manifest=JSON.parse(await readFile('dist/manifest.webmanifest','utf8'));
for(const file of ['index.html','app.js','api.js','config.js','style.css','sw.js','pwa.js',...manifest.icons.map(i=>i.src.replace(/^\//,''))])await access('dist/'+file);
for(const file of await readdir('dist'))if(file.endsWith('.js'))execFileSync(process.execPath,['--check','dist/'+file],{stdio:'inherit'});
console.log('WMS: arquivos, manifesto e JavaScript validados.');
