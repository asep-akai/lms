import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["editor", "toggle"]

  toggle() {
    this.editorTarget.hidden = !this.editorTarget.hidden
    this.toggleTarget.textContent = this.editorTarget.hidden ? this.toggleTarget.dataset.closedLabel : "Close editor"
    this.editorTarget.querySelector("[contenteditable]")?.focus()
  }
}
