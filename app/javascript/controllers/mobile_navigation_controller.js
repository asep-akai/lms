import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "menu"]

  connect() {
    this.breakpoint = window.matchMedia("(min-width: 80rem)")
    this.reset = () => this.close()
    this.breakpoint.addEventListener("change", this.reset)
    this.close()
  }

  disconnect() {
    this.breakpoint.removeEventListener("change", this.reset)
  }

  toggle() {
    const open = this.toggleTarget.getAttribute("aria-expanded") !== "true"
    this.toggleTarget.setAttribute("aria-expanded", String(open))
    this.menuTarget.dataset.open = String(open)
  }

  close() {
    if (!this.hasToggleTarget) return
    this.toggleTarget.setAttribute("aria-expanded", "false")
    this.menuTarget.dataset.open = "false"
  }

  outside(event) {
    if (!this.hasMenuTarget || this.menuTarget.contains(event.target) || this.toggleTarget.contains(event.target)) return
    this.close()
  }

  escape() {
    if (!this.hasToggleTarget || this.toggleTarget.getAttribute("aria-expanded") !== "true") return
    this.close()
    this.toggleTarget.focus()
  }
}
