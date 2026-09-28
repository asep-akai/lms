import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "panel", "search", "option", "empty", "input", "summary", "toggleLabel"]

  connect() {
    if (!this.hasPanelTarget) return

    const selected = this.optionTargets.find((option) => option.dataset.value === this.inputTarget.value)
    if (selected) this.setSelection(selected)
  }

  toggle(event) {
    event.preventDefault()
    this.panelTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.panelTarget.hidden = false
    this.buttonTarget.setAttribute("aria-expanded", "true")
    this.toggleLabelTarget.textContent = "Close list"
    this.searchTarget.focus()
  }

  close() {
    if (!this.hasPanelTarget) return

    this.panelTarget.hidden = true
    this.buttonTarget.setAttribute("aria-expanded", "false")
    this.toggleLabelTarget.textContent = "Open list"
  }

  select(event) {
    this.setSelection(event.currentTarget)
    this.close()
    this.buttonTarget.focus()
  }

  setSelection(selected) {
    this.inputTarget.value = selected.dataset.value
    this.summaryTarget.textContent = selected.dataset.label
    this.optionTargets.forEach((option) => option.setAttribute("aria-selected", option === selected ? "true" : "false"))
  }

  filter() {
    const query = this.searchTarget.value.trim().toLocaleLowerCase()
    let visible = 0

    this.optionTargets.forEach((option) => {
      const matches = option.dataset.search.includes(query)
      option.hidden = !matches
      if (matches) visible += 1
    })

    this.emptyTarget.hidden = visible > 0
  }

  closeOnOutside(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  closeOnEscape(event) {
    if (!this.hasPanelTarget || this.panelTarget.hidden || event.key !== "Escape") return

    this.close()
    this.buttonTarget.focus()
  }
}
