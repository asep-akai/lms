import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages"]

  connect() {
    this.scrollToLatest()
    this.observer = new MutationObserver(() => this.scrollToLatest())
    this.observer.observe(this.messagesTarget, { childList: true })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  scrollToLatest() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }
}
