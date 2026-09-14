import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["type", "multipleChoice", "shortAnswer"]

  connect() {
    this.update()
  }

  update() {
    const multipleChoice = this.typeTarget.value === "multiple_choice"
    this.multipleChoiceTarget.hidden = !multipleChoice
    this.shortAnswerTarget.hidden = multipleChoice
    this.multipleChoiceTarget.querySelectorAll("input").forEach((input) => {
      input.disabled = !multipleChoice
    })
    this.multipleChoiceTarget.querySelectorAll("input[type='text']").forEach((input, index) => {
      input.required = multipleChoice && index < 2
    })
    const shortAnswer = this.shortAnswerTarget.querySelector("input")
    shortAnswer.disabled = multipleChoice
    shortAnswer.required = !multipleChoice
  }
}
