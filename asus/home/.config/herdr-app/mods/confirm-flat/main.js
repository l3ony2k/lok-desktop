// Square copy of Herdr's confirm dialog (the shipped `confirm` cannot be
// edited; it is restored on every start). Enter confirms, Esc cancels.
// Opened with frame: "none" and props { title, detail?, command: { name, args } }.
// The command must already carry its confirmation (confirmed: true).

import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { run, props, closeOverlay, theme } from "herdr";

export default class ConfirmFlat extends View {
  init(_props, cx) {
    this.handle = cx.focus_handle();
    this.handle.focus();
  }

  yes() {
    const p = props();
    closeOverlay(p.overlay);
    run(p.command.name, p.command.args ?? {});
  }

  render() {
    const t = theme();
    const p = props() ?? {};
    const button = (id, label, primary, action) => h_flex().id(id).h(30).px(12).items_center().rounded(0)
      .border_1().border_color(primary ? t.accent : t.input).bg(primary ? t.accent : t.raised)
      .text_color(primary ? t.accent_foreground : t.foreground).text_size(12)
      .when(primary, el => el.font_semibold()).cursor_pointer()
      .hover(s => s.opacity(0.88)).on_click(action).child(label);
    return v_flex().id("confirm-flat").track_focus(this.handle)
      .on_key_down((e, cx) => {
        if (e.key === "enter") this.yes();
        else if (e.key === "escape") closeOverlay(p.overlay);
        else return;
        cx.stop_propagation();
      })
      .w_full().min_h(0).p(16).gap(12).bg(t.popover).border_1().border_color(t.border).text_color(t.foreground)
      .child(h_flex().items_center()
        .child(div().flex_1().text_size(13).font_semibold().child(p.title ?? "Are you sure?"))
        .child(div().text_size(11).text_color(t.dim).child("Esc")))
      .child(div().flex_1().min_h(0).overflow_y_scrollbar().text_size(12).text_color(t.muted).child(p.detail ?? ""))
      .child(h_flex().justify_end().gap(8)
        .child(button("cf-no", "Cancel", false, () => closeOverlay(p.overlay)))
        .child(button("cf-yes", "Confirm", true, () => this.yes())));
  }
}
