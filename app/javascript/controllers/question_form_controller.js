import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  clearChoiceValidation(event) {
    if (event.target.matches("input[type='checkbox'][name$='[correct]']")) {
      this.element.querySelectorAll("input[type='checkbox'][name$='[correct]']").forEach((choice) => choice.setCustomValidity(""))
    }
  }

  synchronize(event) {
    this.element.querySelectorAll("[data-controller~='rich-text-editor']").forEach((element) => {
      element.dispatchEvent(new CustomEvent("rich-text-editor:synchronize"))
    })

    const questionType = this.element.querySelector("select[name$='[question_type]']")
    const choices = Array.from(this.element.querySelectorAll("input[type='checkbox'][name$='[correct]']"))
    const correctChoices = choices.filter((choice) => choice.checked)

    choices.forEach((choice) => choice.setCustomValidity(""))
    const valid = questionType?.value === "multiple_choice" ?
      correctChoices.length === 1 :
      questionType?.value === "multiple_choice_set" ? correctChoices.length >= 1 : true
    if (valid) return

    event.preventDefault()
    const message = questionType?.value === "multiple_choice_set" ?
      "Choose at least one correct answer." :
      "Choose exactly one correct answer."
    choices[0]?.setCustomValidity(message)
    choices[0]?.reportValidity()
  }
}
