import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["key", "keyError"]
  static values = { existingKeys: Array }

  validate(event) {
    if (!this.hasKeyTarget || this.keyTarget.disabled) return
    if (this.validateKey()) return

    event.preventDefault()
    this.keyTarget.focus()
    this.keyTarget.reportValidity()
  }

  validateKey() {
    const key = this.keyTarget.value.trim()
    let message = ""

    if (key && !/^[a-z0-9]+(?:_[a-z0-9]+)*$/.test(key)) {
      message = "Use lowercase letters and numbers separated by single underscores."
    } else if (key && this.existingKeysValue.includes(key)) {
      message = "This key is already used by another role. Choose a different key."
    }

    this.keyTarget.setCustomValidity(message)
    this.keyTarget.setAttribute("aria-invalid", message ? "true" : "false")
    this.keyErrorTarget.textContent = message
    this.keyErrorTarget.hidden = !message
    return message === ""
  }
}
