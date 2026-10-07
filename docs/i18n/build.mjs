#!/usr/bin/env node
// docs/<lang>/{index,privacy,tutorial}.html 을 만든다.
//
// 왜 있나: App Store 는 언어마다 개인정보처리방침 · 마케팅 · 지원 URL 을 따로 받는다.
// 루트 페이지(docs/index.html 등)는 JS 로 언어를 바꾸는 한 장짜리라 "그 언어로 된 주소" 가 없다.
// 그래서 언어마다 고정된 페이지를 만든다. 글은 처음부터 그 언어로 박혀 있고
// (<html lang>, 제목, 본문), hreflang · canonical 로 서로를 가리킨다.
//
// 원본은 두 곳이다.
//   - 루트 페이지의 사전(translations 등)에 이미 있는 언어 → 거기서 꺼낸다.
//   - 루트에 없는 언어 → docs/i18n/<lang>/<page>.json (키 이름은 루트 사전과 같다).
// 루트 페이지의 구조(마크업 · CSS · 스크립트)를 고치면 이걸 다시 돌린다:
//   node docs/i18n/build.mjs
//
// ⚠️ 루트 페이지는 그대로 x-default 다. 주소가 앱 · 스토어에 이미 적혀 있어 옮기지 않는다.

import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const DOCS = path.dirname(HERE);
const BASE = 'https://m1zz.github.io/ClipKeyboard/';

export const LANGS = ['ko', 'en', 'zh-Hans', 'zh-Hant', 'ru', 'ja', 'es', 'de', 'fr', 'it', 'pt-BR', 'th', 'vi'];
const NAMES = {
    ko: '한국어', en: 'English', 'zh-Hans': '简体中文', 'zh-Hant': '繁體中文', ru: 'Русский',
    ja: '日本語', es: 'Español', de: 'Deutsch', fr: 'Français', it: 'Italiano',
    'pt-BR': 'Português (Brasil)', th: 'ไทย', vi: 'Tiếng Việt',
};

// 페이지마다 언어를 타는 데이터 상수. 처음 것이 translations(제목 · 본문)다.
const PAGES = {
    'index.html': ['translations', 'PERSONA_META', 'BADGE_LABEL', 'PERSONA_DATA', 'DEMO_SCENARIOS'],
    'privacy.html': ['translations'],
    'tutorial.html': ['translations'],
};
// 언어 폴더 안에 같이 있는 페이지. 나머지 상대 경로는 한 단계 위(../)를 본다.
const SAME_FOLDER = new Set(['index.html', 'privacy.html', 'tutorial.html']);

// ── JS 리터럴 꺼내기 ─────────────────────────────────────────────

function literalRange(src, name) {
    const m = new RegExp(`const ${name}\\s*=\\s*`).exec(src);
    if (!m) throw new Error(`const ${name} 없음`);
    let i = m.index + m[0].length;
    const start = i;
    let depth = 0;
    for (; i < src.length; i++) {
        const c = src[i];
        if (c === '"' || c === "'" || c === '`') {
            const q = c;
            for (i++; i < src.length && src[i] !== q; i++) if (src[i] === '\\') i++;
            continue;
        }
        if (c === '/' && src[i + 1] === '/') { i = src.indexOf('\n', i); continue; }
        if (c === '/' && src[i + 1] === '*') { i = src.indexOf('*/', i) + 1; continue; }
        if (c === '{' || c === '[') depth++;
        else if (c === '}' || c === ']') { depth--; if (depth === 0) return [start, i + 1]; }
    }
    throw new Error(`${name} 끝을 못 찾음`);
}

function evalLiteral(src, name, ctx) {
    const [a, b] = literalRange(src, name);
    return vm.runInNewContext('(' + src.slice(a, b) + ')', ctx);
}

// ── HTML 손질 ──────────────────────────────────────────────────

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const attr = (s) => esc(s).replace(/"/g, '&quot;');

// 여는 태그 뒤에서 같은 이름의 닫는 태그 위치를 찾는다(중첩 고려).
function closeIndex(html, tag, from) {
    const re = new RegExp(`<(/?)${tag}\\b[^>]*>`, 'gi');
    re.lastIndex = from;
    let depth = 1, m;
    while ((m = re.exec(html))) {
        if (m[1]) { if (--depth === 0) return m.index; } else depth++;
    }
    throw new Error(`</${tag}> 없음`);
}

// data-i18n / data-i18n-html / data-i18n-ph 를 미리 채운다(스크립트 밖에서만).
function prerender(body, t) {
    const re = /<([a-zA-Z0-9]+)\b[^>]*\sdata-i18n(-html|-ph)?="([^"]+)"[^>]*>/g;
    let out = '', last = 0, m;
    while ((m = re.exec(body))) {
        const [open, tag, kind, key] = m;
        if (t[key] === undefined) continue;
        if (kind === '-ph') {
            const tagText = /\splaceholder="[^"]*"/.test(open)
                ? open.replace(/\splaceholder="[^"]*"/, ` placeholder="${attr(t[key])}"`)
                : open.replace(/>$/, ` placeholder="${attr(t[key])}">`);
            out += body.slice(last, m.index) + tagText;
            last = m.index + open.length;
            continue;
        }
        const innerStart = m.index + open.length;
        const innerEnd = closeIndex(body, tag, innerStart);
        out += body.slice(last, innerStart) + (kind === '-html' ? t[key] : esc(t[key]));
        last = innerEnd;
        re.lastIndex = innerEnd;
    }
    return out + body.slice(last);
}

// 스크립트 블록은 건드리지 않고 나머지에만 fn 을 적용한다.
function outsideScripts(html, fn) {
    const parts = html.split(/(<script\b[\s\S]*?<\/script>)/);
    return parts.map((p, i) => (i % 2 ? p : fn(p))).join('');
}

// 상대 경로를 언어 폴더 기준으로 고친다. (HTML 속성 · JS 문자열 · JSON 안의 이스케이프 따옴표 모두)
function rebase(html) {
    return html.replace(/\b(href|src|poster)=(\\?["'])([^"'\\]*)/g, (all, a, q, url) => {
        if (!url || /^(#|[a-z]+:|\/|\.\.\/|\{)/i.test(url)) return all;
        const file = url.split(/[?#]/)[0];
        if (SAME_FOLDER.has(file)) {
            // 같은 폴더의 그 언어 페이지로. ?lang= 은 필요 없다.
            return `${a}=${q}${url.replace(/\?lang=[^#]*/, '')}`;
        }
        return `${a}=${q}../${url}`;
    });
}

function langMenu(page, current) {
    const target = page === 'index.html' ? '' : page;
    const rows = LANGS.map((l) =>
        `            <a href="../${l}/${target}" hreflang="${l}" lang="${l}"${l === current ? ' aria-current="page"' : ''}>${NAMES[l]}</a>`);
    return '<details class="lang-menu">\n' +
        `        <summary><span aria-hidden="true">🌐</span> <span class="lang-menu-label">${NAMES[current]}</span></summary>\n` +
        '        <nav class="lang-menu-list" aria-label="Language">\n' + rows.join('\n') + '\n        </nav>\n    </details>';
}

function headLinks(page, current) {
    const target = page === 'index.html' ? '' : page;
    const lines = [`    <link rel="canonical" href="${BASE}${current}/${target}">`];
    for (const l of LANGS) lines.push(`    <link rel="alternate" hreflang="${l}" href="${BASE}${l}/${target}">`);
    lines.push(`    <link rel="alternate" hreflang="x-default" href="${BASE}${target}">`);
    return lines.join('\n');
}

function setMeta(html, sel, value) {
    if (value === undefined) return html;
    const re = new RegExp(`(<meta ${sel} content=")[^"]*(")`);
    return html.replace(re, `$1${attr(value)}$2`);
}

// ── 만들기 ────────────────────────────────────────────────────

function build(page) {
    const src = fs.readFileSync(path.join(DOCS, page), 'utf8');
    const ctx = {};
    if (page === 'index.html') ctx.TINT = evalLiteral(src, 'TINT', {});
    const consts = PAGES[page];
    const rootData = Object.fromEntries(consts.map((n) => [n, evalLiteral(src, n, ctx)]));

    for (const lang of LANGS) {
        let data;
        if (rootData.translations[lang]) {
            data = Object.fromEntries(consts.map((n) => [n, rootData[n][lang]]));
        } else {
            const f = path.join(HERE, lang, page.replace('.html', '.json'));
            if (!fs.existsSync(f)) { console.warn(`건너뜀: ${lang}/${page} (원본 ${path.relative(DOCS, f)} 없음)`); continue; }
            data = JSON.parse(fs.readFileSync(f, 'utf8'));
        }
        const t = data.translations;
        for (const n of consts) if (!data[n]) throw new Error(`${lang}/${page}: ${n} 없음`);
        const missing = Object.keys(rootData.translations.en).filter((k) => t[k] === undefined);
        if (missing.length) throw new Error(`${lang}/${page}: 번역 없는 키 ${missing.join(', ')}`);

        let html = src;

        // 스크립트의 데이터 상수를 이 언어(+ 대체용 en)만 남긴다. 뒤에서부터 바꿔야 위치가 안 밀린다.
        const ranges = consts.map((n) => [n, ...literalRange(html, n)]).sort((x, y) => y[1] - x[1]);
        for (const [n, a, b] of ranges) {
            const subset = { [lang]: data[n] };
            if (lang !== 'en') subset.en = rootData[n].en;
            html = html.slice(0, a) + JSON.stringify(subset, null, 1) + html.slice(b);
        }

        // 머리
        html = html.replace(/<html lang="[^"]*">/, `<html lang="${lang}">`);
        html = html.replace(/<title>[\s\S]*?<\/title>/, `<title>${esc(t.pageTitle)}</title>`);
        html = html.replace(/\n\s*<link rel="(canonical|alternate)"[^>]*>/g, '');
        html = html.replace(/(\n[^\n]*<meta name="viewport"[^\n]*\n)/,
            `$1${headLinks(page, lang)}\n    <script>window.PAGE_LANG = ${JSON.stringify(lang)};</script>\n`);
        html = html.replace(/\n\s*<meta name="keywords"[^>]*>/, '');
        const desc = t.metaDescription;
        const ogTitle = t.ogTitle || t.pageTitle;
        const ogDesc = t.ogDescription || desc;
        html = setMeta(html, 'name="description"', desc);
        html = setMeta(html, 'property="og:title"', ogTitle);
        html = setMeta(html, 'property="og:description"', ogDesc);
        html = setMeta(html, 'name="twitter:title"', ogTitle);
        html = setMeta(html, 'name="twitter:description"', ogDesc);
        html = setMeta(html, 'property="og:url"', `${BASE}${lang}/${page === 'index.html' ? '' : page}`);

        // 몸통
        html = html.replace(/<details class="lang-menu">[\s\S]*?<\/details>/, langMenu(page, lang));
        html = outsideScripts(html, (part) => prerender(part, t));
        if (t.appStoreUrl) {
            html = html.replace(/(<a\b[^>]*\bid="(?:hero-cta|pricing-cta|footer-appstore|demo-cta|nav-appstore|bottom-cta)"[^>]*\bhref=")[^"]*(")/g,
                `$1${t.appStoreUrl}$2`);
        }
        html = rebase(html);
        html = html.replace(/(['"])media\//g, '$1../media/');

        const outDir = path.join(DOCS, lang);
        fs.mkdirSync(outDir, { recursive: true });
        const banner = `<!-- 만든 파일입니다. 고치려면 docs/${page} 또는 docs/i18n/${lang}/ 를 고치고 node docs/i18n/build.mjs -->\n`;
        fs.writeFileSync(path.join(outDir, page), html.replace(/^<!DOCTYPE html>\n/i, (d) => d + banner));
        console.log(`${lang}/${page}`);
    }
}

for (const page of Object.keys(PAGES)) build(page);
