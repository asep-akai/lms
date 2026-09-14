import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = { unansweredCount: Number, currentAnswerSaved: Boolean }

  async confirm(event) {
    if (this.confirmed) return

    const unansweredCount = this.adjustedUnansweredCount()
    event.preventDefault()
    event.stopImmediatePropagation()
    const message = unansweredCount === 0 ?
      "All questions are answered. Submit quiz?" :
      `${unansweredCount} ${unansweredCount === 1 ? "question is" : "questions are"} unanswered. Submit anyway?`
    const confirmed = await Turbo.config.forms.confirm(message)

    if (confirmed) {
      this.confirmed = true
      const submissionIntent = document.createElement("input")
      submissionIntent.type = "hidden"
      submissionIntent.name = "submit_attempt"
      submissionIntent.value = "1"
      this.element.append(submissionIntent)
      this.element.submit()
    }
  }

  adjustedUnansweredCount() {
    const currentAnswered = this.element.querySelector("input[type='radio']:checked") ||
      this.element.querySelector("textarea")?.value.trim()
    const adjustment = this.currentAnswerSavedValue === Boolean(currentAnswered) ? 0 : (currentAnswered ? -1 : 1)
    return this.unansweredCountValue + adjustment
  }
}
