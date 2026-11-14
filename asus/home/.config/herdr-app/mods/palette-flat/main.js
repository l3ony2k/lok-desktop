// The frame's command palette: everything you can do, by name, with its key.
// Places (spaces, tabs) stay in the picker. Fuzzy: your letters in
// order, word starts and runs rank higher. Empty: recent first, then every
// group. Choices are entries of their own ("Layout: Zen"); commands that need
// a name ask for it. Enter runs, ↑/↓ move, Esc closes.
// Personal copy of Herdr's frame/palette: square panel, symbol key hints.
// Opened with `mod.open:palette-flat` (bound to ctrl-shift-p).

import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex, InputState, Input } from "gpui-base";
import { commands, layouts, keys, spaces, focused, run, theme, props, closeOverlay, openOverlay, shared, window as win } from "herdr";

// The list keeps one height while you move: rows and group titles have fixed
// heights, and the window shows as many as fit in LIST_H.
// 10 rows: with the search line it fits the popup (at most 85% of the
// window) down to ~580 px windows at zoom 1.3.
const SHOWN = 10;
const ROW_H = 32;
const HEAD_H = 26;
const LIST_H = SHOWN * ROW_H;
const GROUPS = ["Recent", "Tab", "Pane", "Space", "Layout", "Terminal", "Agent", "Window", "App"];

// The palette's names for commands: [command, args, group, title, keywords].
const NAMED = [
  ["tab.new", {}, "Tab", "New tab", "tab agent new task"],
  ["mod.open", { name: "picker" }, "Tab", "Go to space or tab…", "switch jump find"],
  ["tab.rename", {}, "Tab", "Rename tab", "tab"],
  ["tab.close", {}, "Tab", "Close tab", "tab kill"],
  ["tab.next", {}, "Tab", "Next tab", "tab"],
  ["tab.prev", {}, "Tab", "Previous tab", "tab"],
  ["pane.split", { direction: "right" }, "Pane", "Split right", "vertical"],
  ["pane.split", { direction: "down" }, "Pane", "Split down", "horizontal"],
  ["pane.close", {}, "Pane", "Close pane", "kill"],
  ["pane.zoom", {}, "Pane", "Zoom pane", "maximize fullscreen"],
  ...["left", "right", "up", "down"].map((d) => ["pane.go", { direction: d }, "Pane", `Focus pane ${d}`, "move go"]),
  ...["left", "right", "up", "down"].map((d) => ["pane.swap", { direction: d }, "Pane", `Swap pane ${d}`, "move"]),
  ["space.new", {}, "Space", "New space", "workspace"],
  ["space.rename", {}, "Space", "Rename space", "workspace"],
  ["space.close", {}, "Space", "Close space", "workspace kill"],
  ["space.next", {}, "Space", "Next space", "workspace"],
  ["space.prev", {}, "Space", "Previous space", "workspace"],
  ["layout.switch", {}, "Layout", "Next layout", "look switch"],
  ["layout.reset", {}, "Layout", "Reset layout", "new version default restore herdr's"],
  ["layout.clone", {}, "Layout", "Duplicate layout", "clone copy customize"],
  ["mod.clone", {}, "Layout", "Duplicate mod", "clone copy customize"],
  ["terminal.open", {}, "Terminal", "New terminal", "shell"],
  ["terminal.copy", {}, "Terminal", "Copy", "clipboard"],
  ["terminal.paste", {}, "Terminal", "Paste", "clipboard"],
  ["agent.next", {}, "Agent", "Next agent", ""],
  ["agent.prev", {}, "Agent", "Previous agent", ""],
  ["window.minimize", {}, "Window", "Minimize window", ""],
  ["window.maximize", {}, "Window", "Maximize window", "restore"],
  ["window.close", {}, "Window", "Close window", "quit"],
  ["mod.open", { name: "settings-flat" }, "App", "Settings", "preferences options config look font theme sound"],
  ["app.help", {}, "App", "Keys", "keybindings shortcuts help"],
  ["app.welcome", {}, "App", "Welcome", "intro start onboarding"],
  ["app.whats_new", {}, "App", "What's new", "release changes news update"],
  ["app.reset", {}, "App", "Reset to the default screen", "escape hatch broken restore"],
  ["app.zoom_in", {}, "App", "Zoom in", "bigger font size"],
  ["app.zoom_out", {}, "App", "Zoom out", "smaller font size"],
  ["app.zoom_reset", {}, "App", "Reset zoom", "font size"],
  ["app.quit", {}, "App", "Quit Herdr", "exit"],
  ...["graphite", "ink", "moss", "atom-one-dark"].map((n) => ["app.theme", { name: n }, "App", `Theme: ${n.replace(/-/g, " ")}`, "colors look"]),
];

// Commands that act on something you point at (ids, terminals): not for a list.
const HIDDEN = new Set([
  "space.move", "tab.move", "space.select", "tab.select", "pane.focus", "terminal.keep",
  "terminal.park", "terminal.kill", "terminal.show", "agent.focus", "layout.set", "layout.toggle",
  "layout.show", "layout.hide", "layout.resize", "layout.select", "mod.open", "overlay.close",
  "tab.settle", "tab.unsettle",
  "app.palette", "app.hide", "app.hide_others", "app.show_all", "app.theme", "app.settings",
]);

function titleOf(name) {
  const [noun, verb] = name.split(".");
  return { group: noun.charAt(0).toUpperCase() + noun.slice(1), title: `${verb.replace(/_/g, " ")} ${noun}`.replace(/^./, (c) => c.toUpperCase()) };
}

// Every entry for the state we're in now.
function entries() {
  const known = new Set(commands().map((c) => c.name));
  const mac = win()?.platform === "macos";
  const list = NAMED.filter(([n]) => known.has(n))
    .filter(([n]) => !(mac && n.startsWith("window.")))
    .map(([name, args, group, title, words]) => ({ name, args, group, title, words }));
  for (const l of layouts()) {
    const t = { main: "Herdr", terminals: "Terminals", win98: "Herdr 98" }[l] ?? l.charAt(0).toUpperCase() + l.slice(1);
    list.push({ name: "layout.switch", args: { name: l }, group: "Layout", title: `Layout: ${t}`, words: `look ${l}` });
  }
  // Anything new in the app shows up too, until it gets a better name here.
  const named = new Set(NAMED.map(([n]) => n));
  for (const c of commands()) {
    if (named.has(c.name) || HIDDEN.has(c.name) || c.args.some((a) => a.required && a.name !== "name")) continue;
    list.push({ name: c.name, args: {}, ...titleOf(c.name), words: c.about });
  }
  return list.map((e) => ({ ...e, id: `${e.name}:${JSON.stringify(e.args)}` }));
}

// The key bound to an entry: `name` or `name:value` in keys.json.
function keyOf(e, bound) {
  const v = Object.values(e.args)[0];
  const want = v === undefined ? e.name : `${e.name}:${v}`;
  const alias = { "tab.rename": "tabs-flat.rename", "space.rename": "spaces-flat.rename", "tab.close": "tabs-flat.close" }[e.name];
  const k = bound.find((b) => b.section === "global" && (b.action === want || b.action === alias));
  return k ? k.keys : null;
}

// "ctrl-shift-p" -> ["ctrl", "shift", "p"]; "ctrl--" -> ["ctrl", "-"].
function keyParts(k) {
  return k.endsWith("--") ? [...k.slice(0, -2).split("-"), "-"] : k.split("-");
}

// Short symbols, space-separated: "ctrl-shift-t" → "⌃ ⇧ T".
function pretty(k) {
  const mod = { ctrl: "⌃", control: "⌃", shift: "⇧", alt: "⌥", option: "⌥", super: "⌘", cmd: "⌘", win: "⌘", meta: "⌘" };
  return keyParts(k).map((p) => mod[p.toLowerCase()] ?? p.toUpperCase()).join(" ");
}

// Fuzzy score of `q` in `text`, with the matched positions; null: no match.
function fuzzy(q, text) {
  const t = text.toLowerCase();
  let score = 0;
  let at = 0;
  let run = 0;
  const hits = [];
  for (const ch of q) {
    const i = t.indexOf(ch, at);
    if (i < 0) return null;
    const start = i === 0 || /[\s:.\-_/]/.test(t[i - 1]);
    run = i === at && hits.length ? run + 1 : 0;
    score += 1 + (start ? 6 : 0) + run * 3 - Math.min(i - at, 6) * 0.3;
    hits.push(i);
    at = i + 1;
  }
  return { score: score - text.length * 0.02, hits };
}

// The square dialogs, opened instead of the shipped ones (Herdr restores
// mods/prompt and mods/confirm on every start, so they cannot be restyled).
function activeSpace() {
  return spaces().find((s) => s.id === focused()?.space) ?? spaces().find((s) => s.active);
}

function activeTab() {
  const s = activeSpace();
  return s?.tabs?.find((t) => t.id === focused()?.tab) ?? s?.tabs?.find((t) => t.active);
}

function renameTab() {
  const tab = activeTab();
  if (!tab) return;
  openOverlay({ mod: "prompt-flat", kind: "dialog", width: 380, frame: "none", props: {
    title: "Rename tab",
    hint: "empty: its number",
    value: tab.named ? tab.name : "",
    command: { name: "tab.rename", args: { id: tab.id } },
  } });
}

function renameSpace() {
  const s = activeSpace();
  if (!s) return;
  openOverlay({ mod: "prompt-flat", kind: "dialog", width: 380, frame: "none", props: {
    title: "Rename space",
    hint: "empty: named after its folder",
    value: s.named ? s.name : "",
    command: { name: "space.rename", args: { id: s.id } },
  } });
}

function closeTab() {
  const s = activeSpace(), tab = activeTab();
  if (!tab) return;
  // Herdr only asks when the last tab would take its space with it.
  if ((s.tabs?.length ?? 0) > 1) return run("tab.close", { id: tab.id });
  openOverlay({ mod: "confirm-flat", kind: "dialog", width: 380, frame: "none", props: {
    title: `Close tab "${tab.name}"?`,
    detail: "It is the last tab in its space, so the space closes too and its terminals end.",
    command: { name: "tab.close", args: { id: tab.id, confirmed: true } },
  } });
}

function closeSpace() {
  const s = activeSpace();
  if (!s) return;
  openOverlay({ mod: "confirm-flat", kind: "dialog", width: 380, frame: "none", props: {
    title: `Close space "${s.name}"?`,
    detail: "Its terminals end. Anything running in them stops.",
    command: { name: "space.close", args: { id: s.id, confirmed: true } },
  } });
}

export default class Palette extends View {
  init(_props, cx) {
    this.query = "";
    this.input = InputState.new({ placeholder: "Type a command…" });
    this.input.on("change", (_e, cx) => { this.query = this.input.value(); this.at = 0; cx.notify(); });
    this.input.on("submit", () => this.go(this.rows()[this.at]?.e));
    this.input.focus();
    cx.timer.after(600, () => this.input.focus());
    this.at = 0;
    // How far the list is scrolled, px.
    this.scroll = 0;
    this.recent = JSON.parse(localStorage.getItem("recent") ?? "[]");
    this.handle = cx.focus_handle();
  }

  close() {
    closeOverlay(props().overlay);
  }

  go(e) {
    if (!e) return;
    this.recent = [e.id, ...this.recent.filter((r) => r !== e.id)].slice(0, 20);
    localStorage.setItem("recent", JSON.stringify(this.recent));
    this.close();
    if (e.name === "mod.clone") {
      openOverlay({ mod: "prompt-flat", kind: "dialog", width: 380, frame: "none", props: {
        title: "Duplicate mod", hint: "Mod to copy; creates <name>-copy",
        command: { name: "mod.clone", args: {} },
      } });
    } else if (e.name === "tab.rename") renameTab();
    else if (e.name === "space.rename") renameSpace();
    else if (e.name === "tab.close") closeTab();
    else if (e.name === "space.close") closeSpace();
    else {
      run(e.name, e.name === "layout.clone" ? { name: shared("layout") ?? "main" } : e.args);
    }
  }

  // The rows to show: grouped when empty, ranked while typing.
  rows() {
    const all = entries();
    const q = this.query.trim().toLowerCase().replace(/\s+/g, "");
    if (!q) {
      const recent = this.recent.map((id) => all.find((e) => e.id === id)).filter(Boolean).slice(0, 5);
      const rest = GROUPS.slice(1).flatMap((g) => all.filter((e) => e.group === g && !recent.includes(e)));
      const others = all.filter((e) => !GROUPS.includes(e.group) && !recent.includes(e));
      return [...recent.map((e) => ({ e, head: "Recent" })), ...[...rest, ...others].map((e) => ({ e, head: e.group }))];
    }
    const rank = (e) => this.recent.indexOf(e.id);
    return all
      .map((e) => {
        const title = fuzzy(q, e.title);
        const more = fuzzy(q, `${e.group} ${e.title} ${e.name} ${e.words}`);
        const best = title ?? (more && { score: more.score - 4, hits: [] });
        return best && { e, score: best.score, hits: best.hits };
      })
      .filter(Boolean)
      .sort((a, b) => b.score - a.score || (rank(a.e) < 0 ? 99 : rank(a.e)) - (rank(b.e) < 0 ? 99 : rank(b.e)));
  }

  title(t, text, hits, on) {
    if (!hits?.length) return div().text_color(on ? t.foreground : t.muted).child(text);
    const parts = [];
    let cur = "";
    let lit = false;
    [...text].forEach((ch, i) => {
      const h = hits.includes(i);
      if (h !== lit && cur) {
        parts.push([cur, lit]);
        cur = "";
      }
      lit = h;
      cur += ch;
    });
    if (cur) parts.push([cur, lit]);
    return h_flex().children(parts.map(([s, h]) => div().text_color(h ? t.accent : on ? t.foreground : t.muted).when(h, (d) => d.font_semibold()).child(s.replace(/ /g, "\u00a0"))));
  }

  render() {
    const t = theme();
    const rows = this.rows();
    const bound = keys();
    this.at = Math.min(this.at, Math.max(0, rows.length - 1));
    // One continuous strip: each row (and the group title before it) at a
    // fixed y. Scrolling moves the strip in pixels, only as far as it takes to
    // keep the selected row (and its group's title, if it opens one) in view.
    const tops = [];
    let y = 0;
    rows.forEach((r, i) => {
      const head = !this.query && (i === 0 || r.head !== rows[i - 1].head);
      tops.push({ head, title: y, row: y + (head ? HEAD_H : 0) });
      y += (head ? HEAD_H : 0) + ROW_H;
    });
    const total = y;
    const fixed = total > LIST_H;
    this.maxScroll = Math.max(0, total - LIST_H);
    const sel = tops[this.at];
    if (sel) {
      const from = sel.head ? sel.title : sel.row;
      if (from < this.scroll) this.scroll = from;
      if (sel.row + ROW_H > this.scroll + LIST_H) this.scroll = sel.row + ROW_H - LIST_H;
    }
    this.scroll = Math.max(0, Math.min(this.scroll, this.maxScroll));
    const key = (k) => div().text_size(11).text_color(t.dim).child(pretty(k));
    // In a scrolling list each item is placed at its edges from the model
    // above, not stacked: GPUI rounds every height to whole pixels, and a
    // stack of rounded heights drifts away from the model (19 px at zoom 1.3
    // by row 40, cutting the selection off). Edges from the model can't add up.
    const place = (el, start, end) =>
      fixed
        ? el.absolute().left(0).right(0).top(start - this.scroll).bottom(LIST_H - (end - this.scroll))
        : el.flex_none().h(end - start);
    const visible = (start, end) => !fixed || (end > this.scroll && start < this.scroll + LIST_H);
    const list = [];
    rows.forEach((r, i) => {
      const { head, title, row } = tops[i];
      if (head && visible(title, row)) list.push(place(h_flex(), title, row).px(14).pb(4).items_end().text_size(11).font_semibold().text_color(t.dim).child(r.head));
      if (!visible(row, row + ROW_H)) return;
      const on = i === this.at;
      const k = keyOf(r.e, bound);
      list.push(
        place(h_flex(), row, row + ROW_H)
          .id(`pl-${i}`)
          .mx(6)
          .px(10)
          .gap(10)
          .items_center()
          .rounded(0)
          .cursor_pointer()
          .text_size(13)
          .when(on, (el) => el.bg(t.selected))
          .hover((s) => s.bg(t.hover))
          .on_click(() => this.go(r.e))
          .child(div().flex_1().min_w(0).child(this.title(t, r.e.title, r.hits, on)))
          .when(Boolean(this.query), (el) => el.child(div().text_size(11).text_color(t.dim).child(r.e.group)))
          .when(Boolean(k), (el) => el.child(key(k))),
      );
    });
    return v_flex()
      .id("palette")
      .track_focus(this.handle)
      .w_full()
      .min_h(0)
      .p(18)
      .gap(10)
      .bg(t.popover)
      .border_1()
      .border_color(t.border)
      .on_key_down((e, cx) => {
        const k = e.key;
        if (k === "escape") return this.close();
        // Stops at the ends: wrapping jumps out of sight.
        if (k === "down") this.at = Math.min(this.at + 1, rows.length - 1);
        else if (k === "up") this.at = Math.max(this.at - 1, 0);
        else if (k === "pagedown") this.at = Math.min(this.at + SHOWN, rows.length - 1);
        else if (k === "pageup") this.at = Math.max(this.at - SHOWN, 0);
        else return;
        cx.stop_propagation();
        cx.notify();
      })
      .child(
        h_flex()
          .h(36)
          .flex_none()
          .px(10)
          .gap(10)
          .items_center()
          .rounded(0)
          .border_1()
          .border_color(t.accent)
          .bg(t.background)
          .child(svg("mods/palette-flat/command.svg").size(16).text_color(t.dim))
          .child(Input.new(this.input).flex_1().h_full().text_size(13).text_color(t.foreground))
          .child(div().text_size(11).text_color(t.dim).child("Esc")),
      )
      .child(
        rows.length
          ? div()
              .id("palette-rows")
              .relative()
              .mb(6)
              .when(fixed, (el) => el.h(LIST_H).overflow_hidden())
              .on_scroll_wheel((e, cx) => {
                // The event bridge converts both wheel and touchpad deltas to pixels.
                this.scroll = Math.max(0, Math.min(this.scroll - e.delta.y, this.maxScroll));
                // The selection stays on screen, so the next frame doesn't scroll back to it.
                while (this.at < rows.length - 1 && tops[this.at].row < this.scroll) this.at++;
                while (this.at > 0 && tops[this.at].row + ROW_H > this.scroll + LIST_H) this.at--;
                cx.notify();
              })
              .children(fixed ? list : [v_flex().children(list)])
          : div().px(16).py(14).text_size(13).text_color(t.dim).child(`Nothing matches "${this.query}". Places are in the picker.`),
      );
  }
}
