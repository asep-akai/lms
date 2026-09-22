import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "onlineFields", "meetingUrl"]

  connect() {
    this.toggle()
  }

  toggle() {
    const online = this.selectTarget.value === "online"
    this.onlineFieldsTarget.hidden = !online
    this.meetingUrlTarget.required = online
    this.meetingUrlTarget.setAttribute("aria-required", online.toString())
  }
}
