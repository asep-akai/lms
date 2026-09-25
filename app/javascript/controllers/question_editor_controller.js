import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["type", "multipleChoice", "choiceHint", "shortAnswer", "cloze", "essay", "audio", "scoring"]

  connect() {
    this.update()
  }

  update() {
    const type = this.typeTarget.value
    const multipleChoice = type === "multiple_choice"
    const multipleChoiceSet = type === "multiple_choice_set"
    const shortAnswer = this.typeTarget.value === "short_answer"
    const cloze = type === "cloze"
    const essay = this.typeTarget.value === "essay"
    const audio = this.typeTarget.value === "audio"
    const choiceQuestion = multipleChoice || multipleChoiceSet
    this.multipleChoiceTarget.hidden = !choiceQuestion
    if (this.hasChoiceHintTarget) {
      this.choiceHintTarget.textContent = multipleChoiceSet ?
        "Provide at least two choices, with at least one correct and one incorrect." :
        "Provide at least two choices and mark exactly one as correct."
    }
    this.shortAnswerTarget.hidden = !shortAnswer
    if (this.hasClozeTarget) this.clozeTarget.hidden = !cloze
    this.essayTarget.hidden = !essay
    this.audioTarget.hidden = !audio
    if (this.hasScoringTarget) this.scoringTarget.hidden = !(essay || audio)
    this.multipleChoiceTarget.querySelectorAll("input").forEach((input) => {
      input.disabled = !choiceQuestion
    })
    this.multipleChoiceTarget.querySelectorAll("input[type='text']").forEach((input, index) => {
      input.required = choiceQuestion && index < (multipleChoiceSet ? 3 : 2)
    })
    const expectedAnswer = this.shortAnswerTarget.querySelector("input")
    expectedAnswer.disabled = !shortAnswer
    expectedAnswer.required = shortAnswer
    if (this.hasClozeTarget) {
      const clozeTemplate = this.clozeTarget.querySelector("textarea")
      clozeTemplate.disabled = !cloze
      clozeTemplate.required = cloze
    }
    if (this.hasScoringTarget) {
      this.scoringTarget.querySelector("select").disabled = !(essay || audio)
    }
  }
}
