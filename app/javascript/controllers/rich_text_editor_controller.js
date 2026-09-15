import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["editor", "input"]

  connect() {
    this.synchronize()
    this.element.addEventListener("rich-text-editor:synchronize", () => this.synchronize())
  }

  preserveSelection(event) {
    const selection = window.getSelection()
    this.range = selection.rangeCount > 0 ? selection.getRangeAt(0).cloneRange() : null
    event.preventDefault()
  }

  format(event) {
    event.preventDefault()
    this.editorTarget.focus()
    if (this.range) {
      const selection = window.getSelection()
      selection.removeAllRanges()
      selection.addRange(this.range)
    }
    const command = event.currentTarget.dataset.command
    const value = event.currentTarget.dataset.value || null
    if (command === "foreColor") document.execCommand("styleWithCSS", false, true)
    document.execCommand(command, false, value)
    if (command === "foreColor") document.execCommand("styleWithCSS", false, false)
    this.synchronize()
  }

  synchronize() {
    this.inputTarget.value = this.editorTarget.innerHTML
  }
}
