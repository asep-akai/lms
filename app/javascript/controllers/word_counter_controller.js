import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "output"]

  connect() {
    this.update()
  }

  update() {
    const words = this.inputTarget.value.trim().match(/\S+/g) || []
    const label = words.length === 1 ? "word" : "words"

    this.outputTarget.textContent = `${words.length} ${label}`
  }
}
