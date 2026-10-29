// 클립키보드 웹 체험: 앱의 '키보드 미리보기' 화면처럼 키를 누르면 입력칸에 들어간다.
// 규칙은 앱과 같다. 단축어는 그대로, 템플릿은 {빈칸}을 먼저 묻고, 스택은 지금 칸의 값을 넣고 › 로 다음 칸에 간다.
// 키 이름·값은 사용 가이드(tutorial.html)의 실습판과 같은 예시다. 아무것도 저장하거나 보내지 않는다.
(() => {
  const root = document.getElementById("demo");
  if (!root) return;
  const T = JSON.parse(root.dataset.text);
  const esc = s => String(s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);

  const keys = [
    { key: T.bankKey, value: T.bankVal },
    { key: T.lateKey, value: T.lateVal },
    { key: T.helloKey, value: T.helloVal },
    { key: T.stackKey, stack: T.stack }
  ];
  const state = { text: "", sent: [], step: 0, fill: null, coach: T.coachStart };

  root.innerHTML = `
    <div class="ck-phone">
      <div class="ck-convo" aria-live="polite"></div>
      <div class="ck-compose">
        <div class="ck-field"></div>
        <button type="button" class="ck-send" aria-label="${esc(T.send)}">↑</button>
      </div>
      <div class="ck-kb">
        <div class="ck-keys"></div>
        <div class="ck-sheet" hidden>
          <strong>${esc(T.fillTitle)}</strong>
          <label class="ck-slot"><span></span><input type="text" autocomplete="off"></label>
          <div class="ck-row">
            <button type="button" class="ck-no">${esc(T.fillCancel)}</button>
            <button type="button" class="ck-go">${esc(T.fillGo)}</button>
          </div>
        </div>
      </div>
    </div>
    <div class="ck-side">
      <p class="ck-coach" role="status"></p>
      <p class="muted small">${esc(T.note)}</p>
    </div>`;

  const $ = s => root.querySelector(s);
  const sheet = $(".ck-sheet"), input = $(".ck-sheet input");
  const slotsOf = v => (v.match(/\{[^}]+\}/g) || []);

  function render() {
    // 다시 그려도 키보드로 누르던 자리를 잃지 않게 한다.
    const a = document.activeElement, d = a && root.contains(a) ? a.dataset : {};
    const again = d.key ? `[data-key="${d.key}"]` : d.next ? `[data-next="${d.next}"]` : null;
    $(".ck-convo").innerHTML = `<div class="ck-bubble them">${esc(T.them)}</div>` +
      state.sent.map(m => `<div class="ck-bubble me">${esc(m)}</div>`).join("");
    $(".ck-convo").scrollTop = 1e6;
    const field = $(".ck-field");
    field.textContent = state.text || T.field;
    field.classList.toggle("empty", !state.text);
    $(".ck-send").disabled = !state.text;
    $(".ck-keys").innerHTML = keys.map((k, i) => {
      if (!k.stack) return `<button type="button" class="ck-key" data-key="${i}">${esc(k.key)}</button>`;
      const s = k.stack[state.step];
      return `<span class="ck-key ck-stack"><button type="button" data-key="${i}">${esc(k.key)}` +
        `<small>${esc(s.key)} · ${state.step + 1}/${k.stack.length}</small></button>` +
        `<button type="button" class="ck-next" data-next="${i}" aria-label="${esc(s.key)} ›">›</button></span>`;
    }).join("");
    $(".ck-keys").classList.toggle("hint", !root.dataset.used);
    $(".ck-coach").textContent = state.coach;
    if (again) $(again).focus();
  }

  function insert(text) {
    state.text = state.text ? `${state.text} ${text}` : text;
    state.coach = T.coachSend;
    root.dataset.used = "1";
    render();
  }

  function tap(i) {
    const k = keys[i];
    if (k.stack) { insert(k.stack[state.step].value); state.coach = T.coachStack; render(); return; }
    const slot = slotsOf(k.value)[0];
    if (!slot) { insert(k.value); return; }
    state.fill = { i, slot };
    $(".ck-slot span").textContent = slot;
    input.value = "";
    sheet.hidden = false;
    input.focus();
  }

  function fill(go) {
    const f = state.fill;
    state.fill = null;
    sheet.hidden = true;
    if (go && f) insert(keys[f.i].value.split(f.slot).join(input.value.trim() || f.slot));
  }

  root.addEventListener("click", e => {
    const next = e.target.closest("[data-next]");
    if (next) { state.step = (state.step + 1) % T.stack.length; state.coach = T.coachStack; render(); return; }
    const key = e.target.closest("[data-key]");
    if (key) { tap(+key.dataset.key); return; }
    if (e.target.closest(".ck-go")) fill(true);
    else if (e.target.closest(".ck-no")) fill(false);
    else if (e.target.closest(".ck-send") && state.text) {
      state.sent.push(state.text);
      state.text = "";
      state.coach = T.coachDone;
      render();
    }
  });
  input.addEventListener("keydown", e => {
    if (e.key === "Enter") fill(true);
    if (e.key === "Escape") fill(false);
  });

  render();
})();
