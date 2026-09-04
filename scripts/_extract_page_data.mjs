// docs 페이지의 스크립트를 평가해 지정한 상수들을 JSON 으로 내보낸다.
// DOM 은 뭘 물어도 대답하는 인형으로 대신한다 - 상수 선언만 잡으면 되기 때문이다.
import fs from 'node:fs';
import vm from 'node:vm';

const [file, names] = process.argv.slice(2);
const html = fs.readFileSync(file, 'utf8');
const doll = new Proxy(function () {}, {
  get(_t, p) {
    if (p === 'length') return 0;
    if (p === Symbol.iterator) return [][Symbol.iterator].bind([]);
    if (p === Symbol.toPrimitive) return () => '';
    if (p === 'toString' || p === 'valueOf') return () => '';
    if (p === 'then') return undefined;
    return doll;
  },
  set: () => true, apply: () => doll, has: () => true,
});
const ctx = { console: { log() {}, warn() {}, error() {} }, URLSearchParams,
              setTimeout, clearTimeout, setInterval, clearInterval,
              window: doll, document: doll, localStorage: doll, navigator: { language: 'en' } };
vm.createContext(ctx);
const wanted = names.split(',').filter(Boolean);
const out = {};
for (const src of [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1])) {
  const here = wanted.filter((n) => new RegExp(`const\\s+${n}\\s*=`).test(src));
  if (!here.length) continue;
  try {
    vm.runInContext(`${src}\n;globalThis.__D = Object.assign(globalThis.__D || {}, {${here.join(',')}});`, ctx);
  } catch (e) {
    process.stderr.write(`평가 오류: ${e.message}\n`);
  }
}
Object.assign(out, ctx.__D || {});
process.stdout.write(JSON.stringify(out));
