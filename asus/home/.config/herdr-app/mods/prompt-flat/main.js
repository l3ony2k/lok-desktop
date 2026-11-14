// Square copy of Herdr's prompt dialog (the shipped `prompt` cannot be edited;
// it is restored on every start). Enter saves, Esc cancels.
// Opened with frame: "none" and props:
//   { title, hint?, value?, command: { name, args } }
// The mod draws its own panel, so the dialog has no rounded corners.

import { View, div } from "gpui-kit";
import { v_flex, h_flex, InputState, Input } from "gpui-base";
import { run, props, closeOverlay, theme } from "herdr";

export default class PromptFlat extends View {
  init(_props, cx) {
    this.text = props()?.value ?? "";
    this.input = InputState.new({ value: this.text });
    if (this.text) this.input.set_selected_range({ start: 0, end: this.text.length });
    this.input.on("change", (_e, cx) => { this.text = this.input.value(); cx.notify(); });
    this.input.on("submit", () => this.submit());
    this.inputFocused = true;
    this.input.on("focus", (_e, cx) => { this.inputFocused = true; cx.notify(); });
    this.input.on("blur", (_e, cx) => { this.inputFocused = false; cx.notify(); });
    this.input.focus();
    cx.timer.after(600, () => this.input.focus());
    this.handle = cx.focus_handle();
  }

  submit() {
    const p = props();
    const name = this.text;
    closeOverlay(p.overlay);
    run(p.command.name, { ...(p.command.args ?? {}), name });
  }

  key(e, cx) {
    if (e.key === "escape") { closeOverlay(props().overlay); cx.stop_propagation(); }
  }

  render() {
    const t = theme();
    const p = props() ?? {};
    const label = (text) => div().pt(14).pb(6).text_size(11).text_color(t.dim).child(text);
    const button = (id, text, primary, action) => h_flex().id(id).h(30).px(12).items_center().rounded(0)
      .border_1().border_color(primary ? t.accent : t.input).bg(primary ? t.accent : t.raised)
      .text_color(primary ? t.accent_foreground : t.foreground).text_size(12)
      .when(primary, el => el.font_semibold()).cursor_pointer()
      .hover(s => s.opacity(0.88)).on_click(action).child(text);
    return v_flex().id("prompt-flat").track_focus(this.handle).on_key_down((e, cx) => this.key(e, cx))
      .w_full().min_h(0).p(16).bg(t.popover).border_1().border_color(t.border).text_color(t.foreground)
      .child(h_flex().items_center()
        .child(div().flex_1().text_size(13).font_semibold().child(p.title ?? ""))
        .child(div().text_size(11).text_color(t.dim).child("Esc")))
      .child(label("Name"))
      .child(Input.new(this.input).h(34).px(10).rounded(0).border_1().border_color(this.inputFocused ? t.accent : t.input).bg(t.background).text_size(13).text_color(t.foreground))
      .when(Boolean(p.hint), el => el.child(div().pt(6).text_size(11).text_color(t.dim).child(p.hint)))
      .child(h_flex().pt(18).gap(8).justify_end()
        .child(button("pm-cancel", "Cancel", false, () => closeOverlay(p.overlay)))
        .child(button("pm-save", "Save", true, () => this.submit())));
  }
}
