import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = { unansweredCount: Number, currentAnswerSaved: Boolean, answerKind: String }

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
    const currentAnswered = this.currentAnswerComplete()
    const adjustment = this.currentAnswerSavedValue === Boolean(currentAnswered) ? 0 : (currentAnswered ? -1 : 1)
    return this.unansweredCountValue + adjustment
  }

  currentAnswerComplete() {
    if (this.answerKindValue === "multiple_choice") {
      return Boolean(this.element.querySelector("input[type='radio']:checked"))
    }
    if (this.answerKindValue === "multiple_choice_set") {
      return Boolean(this.element.querySelector("input[type='checkbox'][name='quiz_answer[selected_option_ids][]']:checked"))
    }
    if (this.answerKindValue === "cloze") {
      const blanks = Array.from(this.element.querySelectorAll("input[name^='quiz_answer[cloze_responses]']"))
      return blanks.length > 0 && blanks.every((input) => input.value.trim())
    }
    if (this.answerKindValue === "audio") {
      return this.element.querySelector("input[type='file']")?.files.length > 0 ||
        Boolean(this.element.querySelector("[data-answer-present='true']"))
    }

    return Boolean(this.element.querySelector("textarea")?.value.trim())
  }
}
