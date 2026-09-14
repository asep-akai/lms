import { Controller } from "@hotwired/stimulus"
import { makeDialogDismissible } from "dialog"

export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    this.removeDismissibleBehavior = makeDialogDismissible(this.dialogTarget, (event) => this.close(event))
    this.dialogTarget.showModal?.()
  }

  disconnect() {
    this.removeDismissibleBehavior?.()
  }

  close(event) {
    event?.preventDefault()
    this.element.remove()
  }

}
