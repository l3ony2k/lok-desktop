// A shim for terminal right-clicks: the app opens that popup itself, with its
// own rounded frame that a mod cannot turn off. Close it at once and open the
// same menu frameless, so it matches the other (square) menus.
import { View, div } from "gpui-kit";
import { props, closeOverlay, openOverlay } from "herdr";

export default class TerminalMenu extends View {
  init() {
    const p = props();
    if (!p?.overlay) return;
    closeOverlay(p.overlay);
    openOverlay({
      mod: "menu-flat",
      kind: "popup",
      frame: "none",
      width: 320,
      props: { tab: "pane", target: p.target, bare: true },
    });
  }

  render() {
    return div();
  }
}
