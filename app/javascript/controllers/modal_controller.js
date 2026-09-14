import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    this.dialogTarget.showModal?.()
  }

  close() {
    this.element.remove()
  }

  backdrop(event) {
    if (event.target === this.element) this.close()
  }
}
