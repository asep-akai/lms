import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "output", "status" ]
  static values = { expiresAt: String, formId: String }

  connect() {
    this.tick()
    this.interval = window.setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    window.clearInterval(this.interval)
  }

  tick() {
    const remainingSeconds = Math.max(0, Math.ceil((Date.parse(this.expiresAtValue) - Date.now()) / 1000))
    this.outputTarget.textContent = this.formatDuration(remainingSeconds)

    if (remainingSeconds === 0) this.submitExpiredAttempt()
  }

  submitExpiredAttempt() {
    if (this.submitting) return

    this.submitting = true
    window.clearInterval(this.interval)
    this.outputTarget.textContent = "00:00"
    this.statusTarget.textContent = "Time is up. Submitting your saved answers now."

    const form = document.getElementById(this.formIdValue)
    if (!form) return

    this.addSubmissionIntent(form, "submit_attempt")
    this.addSubmissionIntent(form, "time_expired")
    form.requestSubmit()
  }

  addSubmissionIntent(form, name) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = "1"
    form.append(input)
  }

  formatDuration(totalSeconds) {
    const hours = Math.floor(totalSeconds / 3600)
    const minutes = Math.floor((totalSeconds % 3600) / 60)
    const seconds = totalSeconds % 60
    const parts = hours > 0 ? [ hours, minutes, seconds ] : [ minutes, seconds ]
    return parts.map((part) => String(part).padStart(2, "0")).join(":")
  }
}
