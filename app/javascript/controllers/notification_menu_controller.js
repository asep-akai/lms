import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.closeFromOutside = this.closeFromOutside.bind(this)
    this.closeFromKeyboard = this.closeFromKeyboard.bind(this)
    document.addEventListener("click", this.closeFromOutside)
    document.addEventListener("keydown", this.closeFromKeyboard)
  }

  disconnect() {
    document.removeEventListener("click", this.closeFromOutside)
    document.removeEventListener("keydown", this.closeFromKeyboard)
  }

  closeFromOutside(event) {
    if (this.element.open && !this.element.contains(event.target)) this.element.removeAttribute("open")
  }

  closeFromKeyboard(event) {
    if (event.key !== "Escape" || !this.element.open) return

    this.element.removeAttribute("open")
    this.element.querySelector("summary")?.focus()
  }
}
