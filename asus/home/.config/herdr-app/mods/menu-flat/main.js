// Context menus (Herdr's items). Opened as a popup with
// props { tab: "pane" | "tab" | "space" | "global", target }.
// ↑/↓ move, Enter runs, Esc closes. An item is [label, command, args];
// a command "worktree" opens the worktree dialog instead.

import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { run, props, closeOverlay, openOverlay, theme, keys, terminals, spaces, panes, exec } from "herdr";

// Where a space is now: its first terminal's live folder, else where it was made.
function place(s) {
  const tabs = new Set((s.tabs ?? []).map((c) => c.id));
  return panes().find((p) => tabs.has(p.tab) && p.cwd)?.cwd || s.folder;
}

// A space's checkout: "main" (a repo's own), "linked" (a worktree), or null.
async function checkout(folder, on) {
  const top = await exec("git", ["rev-parse", "--show-toplevel"], { cwd: folder, on });
  const common = await exec("git", ["rev-parse", "--path-format=absolute", "--git-common-dir"], { cwd: folder, on });
  if (top.code !== 0 || common.code !== 0) return null;
  return common.stdout.trim() === `${top.stdout.trim()}/.git` ? "main" : "linked";
}

function items(p, git) {
  p = p ?? {};
  const tg = p.target ?? {};
  switch (p.tab) {
    case "pane": {
      // A kept sub-agent can go back under its parent, still running.
      const all = terminals();
      const term = all.find((t) => t.address === tg.terminal);
      const parent = term?.parent && all.find((t) => t.address === term.parent);
      // Once they go to the program, Shift+right-click still opens this menu.
      const toProgram = term?.labels?.["herdr.right-click"] === "program";
      return [
        ["Split right", "pane.split", { direction: "right", pane: tg.pane }],
        ["Split down", "pane.split", { direction: "down", pane: tg.pane }],
        ["Zoom", "pane.zoom", { pane: tg.pane }],
        ...(term
          ? [
              toProgram
                ? ["Use Herdr right-click menu", "terminal.right_click", { terminal: term.address, to: "menu" }]
                : ["Send right-clicks to pane", "terminal.right_click", { terminal: term.address, to: "program" }],
            ]
          : []),
        ...(parent ? [[`Send back to ${parent.name || parent.address}`, "terminal.park", { terminal: term.address }]] : []),
        ["Close pane", "pane.close", { pane: tg.pane }],
      ];
    }
    case "tab":
      return [
        ["Rename", "tab.rename", { id: tg.id, space: tg.space }],
        ["New tab", "tab.new", { space: tg.space }],
        ["Close", "tab.close", { id: tg.id, space: tg.space }],
      ];
    case "space":
      return [
        ["Rename", "space.rename", { id: tg.id }],
        ...(git ? [["New worktree", "worktree", { space: tg.id, action: "new" }], ["Open worktree", "worktree", { space: tg.id, action: "open" }]] : []),
        ...(git === "linked" ? [["Remove worktree", "worktree", { space: tg.id, action: "remove" }]] : []),
        ["Close", "space.close", { id: tg.id }],
      ];
    default:
      return [
        ["New space", "space.new", {}],
        ["Keybinds", "app.help", {}],
        ["Theme: graphite", "app.theme", { name: "graphite" }],
        ["Theme: ink", "app.theme", { name: "ink" }],
        ["Theme: moss", "app.theme", { name: "moss" }],
        ["Theme: atom one dark", "app.theme", { name: "atom-one-dark" }],
      ];
  }
}

function menuIcon(command, args) {
  // Both split directions used to share panel-right; a split down is a bottom panel.
  if (command === "pane.split" && args?.direction === "down") return "mods/menu-flat/panel-bottom.svg";
  const name = command.endsWith(".close") ? "x" : command.endsWith(".rename") ? "square-pen" : command.endsWith(".new") ? "plus" : command === "worktree" ? "git-branch" : command === "app.help" ? "terminal" : command === "app.theme" ? "settings" : command === "pane.split" ? "panel-right" : command === "pane.zoom" ? "square" : "terminal";
  return `mods/workspace-chrome/${name}.svg`;
}

// A bound key as short symbols, space-separated: "ctrl-shift-o" → "⌃ ⇧ O".
function pretty(keys) {
  const mod = { ctrl: "⌃", control: "⌃", shift: "⇧", alt: "⌥", option: "⌥", super: "⌘", cmd: "⌘", win: "⌘", meta: "⌘" };
  return (keys ?? "").trim().split(/\s+/).map((stroke) => {
    const parts = stroke.endsWith("--") ? [...stroke.slice(0, -2).split("-"), "-"] : stroke.split("-");
    return parts.map((p) => mod[p.toLowerCase()] ?? p.toUpperCase()).join(" ");
  }).join(" ");
}

// The key bound to a command, for the hint on the right.
function shortcut(name, args) {
  // `pane.split:right` binds pane.split with { direction: "right" }. Our own
  // key commands open the square dialogs; the hint still names the command.
  const alias = { "tab.rename": "tabs-flat.rename", "space.rename": "spaces-flat.rename", "tab.close": "tabs-flat.close" }[name];
  const value = args && Object.values(args)[0];
  const k = keys().find((b) => b.section === "global" && (b.action === name || b.action === alias || b.action === `${name}:${value}`));
  return k ? pretty(k.keys) : "";
}

// The square dialogs, opened instead of the shipped ones (Herdr restores
// mods/prompt and mods/confirm on every start, so they cannot be restyled).
function renameTab(args) {
  const s = args.space ? spaces().find((x) => x.id === args.space) : spaces().find((x) => x.active);
  const tab = s?.tabs?.find((t) => t.id === args.id);
  if (!tab) return;
  openOverlay({ mod: "prompt-flat", kind: "dialog", width: 380, frame: "none", props: {
    title: "Rename tab",
    hint: "empty: its number",
    value: tab.named ? tab.name : "",
    command: { name: "tab.rename", args: { id: tab.id } },
  } });
}

function renameSpace(args) {
  const s = spaces().find((x) => x.id === args.id);
  if (!s) return;
  openOverlay({ mod: "prompt-flat", kind: "dialog", width: 380, frame: "none", props: {
    title: "Rename space",
    hint: "empty: named after its folder",
    value: s.named ? s.name : "",
    command: { name: "space.rename", args: { id: s.id } },
  } });
}

function closeTab(args) {
  const s = args.space ? spaces().find((x) => x.id === args.space) : spaces().find((x) => x.active);
  const tab = s?.tabs?.find((t) => t.id === args.id);
  if (!tab) return;
  // Herdr only asks when the last tab would take its space with it.
  if ((s.tabs?.length ?? 0) > 1) return run("tab.close", { id: tab.id });
  openOverlay({ mod: "confirm-flat", kind: "dialog", width: 380, frame: "none", props: {
    title: `Close tab "${tab.name}"?`,
    detail: "It is the last tab in its space, so the space closes too and its terminals end.",
    command: { name: "tab.close", args: { id: tab.id, confirmed: true } },
  } });
}

function closeSpace(args) {
  const s = spaces().find((x) => x.id === args.id);
  if (!s) return;
  openOverlay({ mod: "confirm-flat", kind: "dialog", width: 380, frame: "none", props: {
    title: `Close space "${s.name}"?`,
    detail: "Its terminals end. Anything running in them stops.",
    command: { name: "space.close", args: { id: s.id, confirmed: true } },
  } });
}

export default class Menu extends View {
  init(_props, cx) {
    this.at = 0;
    this.git = null;
    this.handle = cx.focus_handle();
    this.handle.focus();
    const p = props();
    const space = p?.tab === "space" && spaces().find((s) => s.id === p.target?.id);
    const folder = space && place(space);
    if (folder)
      cx.spawn(async (cx) => {
        this.git = await checkout(folder, space.machine).catch(() => null);
        cx.notify();
      });
  }

  choose(i, cx) {
    const it = items(props(), this.git)[i];
    if (!it) return;
    closeOverlay(props()?.overlay);
    const [, cmd, args] = it;
    if (cmd === "worktree") return openOverlay({ mod: "worktree-flat", kind: "dialog", frame: "none", ...(args.action === "open" ? { width: 560, height: 480 } : { width: 440, height: 260 }), props: args });
    if (cmd === "tab.rename") return renameTab(args);
    if (cmd === "space.rename") return renameSpace(args);
    if (cmd === "tab.close") return closeTab(args);
    if (cmd === "space.close") return closeSpace(args);
    run(cmd, args);
  }

  render(cx) {
    const t = theme();
    const list = items(props(), this.git);
    // `bare`: opened frameless (frame: "none"), so the menu draws its own panel.
    const bare = props()?.bare === true;
    return v_flex()
      .id("menu")
      .track_focus(this.handle)
      .w_full()
      .min_h(0)
      .p(5)
      .bg(t.popover)
      .when(bare, (el) => el.size_full().border_1().border_color(t.border))
      .text_size(13)
      .on_key_down((e, cx) => {
        if (e.key === "down") this.at = (this.at + 1) % list.length;
        else if (e.key === "up") this.at = (this.at + list.length - 1) % list.length;
        else if (e.key === "enter") this.choose(this.at, cx);
        else if (e.key === "escape") closeOverlay(props().overlay);
        else return;
        cx.notify();
      })
      .children(
        list.map((it, i) =>
          v_flex()
            .when(i > 0 && (it[1].endsWith(".close") || it[1] === "app.help" || (it[1] === "app.theme" && list[i - 1][1] !== "app.theme")), el => el.child(div().mx(7).my(4).h(1).bg(t.border)))
            .child(h_flex()
            .id(`mi-${i}`)
            .h(31)
            .px(8)
            .gap(9)
            .rounded(0)
            .items_center()
            .justify_between()
            .text_color(t.foreground)
            .when(i === this.at, (el) => el.bg(t.selected))
            .hover((s) => s.bg(t.hover))
            .on_click((_e, cx) => this.choose(i, cx))
            .child(svg(menuIcon(it[1], it[2])).size(14).flex_none().text_color(t.muted))
            .child(div().flex_1().min_w(0).truncate().child(it[0]))
            .child(div().flex_none().text_size(11).text_color(t.dim).child(shortcut(it[1], it[2])))),
        ),
      );
  }
}
