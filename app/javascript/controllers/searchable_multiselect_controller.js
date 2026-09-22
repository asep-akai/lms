import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "panel", "search", "row", "checkbox", "empty", "summary", "toggleLabel", "count"]

  connect() {
    if (!ready(this)) return

    this.updateSummary()
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
    if (!ready(this)) return

    this.panelTarget.hidden = true
    this.buttonTarget.setAttribute("aria-expanded", "false")
    this.toggleLabelTarget.textContent = "Open list"
  }

  closeOnOutside(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  closeOnEscape(event) {
    if (!ready(this) || this.panelTarget.hidden || event.key !== "Escape") return

    this.close()
    this.buttonTarget.focus()
  }

  filter() {
    const query = this.searchTarget.value.trim().toLocaleLowerCase()
    let visibleRows = 0

    this.rowTargets.forEach((row) => {
      const matches = row.dataset.search.includes(query)
      row.hidden = !matches
      if (matches) visibleRows += 1
    })

    this.emptyTarget.hidden = visibleRows > 0
  }

  updateSummary() {
    const selected = this.checkboxTargets.filter((checkbox) => checkbox.checked)

    if (selected.length === 0) {
      this.summaryTarget.textContent = "Select students"
    } else if (selected.length === 1) {
      this.summaryTarget.textContent = selected[0].dataset.label
    } else {
      this.summaryTarget.textContent = `${selected.length} students selected`
    }

    this.countTarget.textContent = `${selected.length} selected`
  }
}

function ready(controller) {
  return controller.hasButtonTarget && controller.hasPanelTarget
}
