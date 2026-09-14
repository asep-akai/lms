import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["questions", "template", "question", "position", "destroy"]

  connect() {
    this.updatePositions()
  }

  addQuestion() {
    const identifier = Date.now().toString()
    const content = this.templateTarget.innerHTML.replaceAll("NEW_QUESTION", identifier)
    this.questionsTarget.insertAdjacentHTML("beforeend", content)
    this.updatePositions()
    this.questionTargets.at(-1)?.querySelector("[contenteditable]")?.focus()
  }

  removeQuestion(event) {
    const question = event.currentTarget.closest("[data-quiz-editor-target='question']")
    question.querySelector("[data-quiz-editor-target='destroy']").value = "1"
    question.hidden = true
    this.updatePositions()
  }

  synchronize() {
    this.element.querySelectorAll("[data-controller~='rich-text-editor']").forEach((element) => {
      element.dispatchEvent(new CustomEvent("rich-text-editor:synchronize"))
    })
  }

  updatePositions() {
    this.questionTargets.filter((question) => !question.hidden).forEach((question, index) => {
      question.querySelector("[data-quiz-editor-target='position']").value = index + 1
    })
  }
}
