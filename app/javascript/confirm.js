import { Turbo } from "@hotwired/turbo-rails"
import { makeDialogDismissible } from "dialog"

Turbo.config.forms.confirm = (message) => new Promise((resolve) => {
  const dialog = document.createElement("dialog")
  dialog.className = "modal-panel"
  dialog.innerHTML = `
    <form method="dialog" class="form-stack">
      <p class="title">Please confirm</p>
      <p class="subtitle"></p>
      <div class="actions">
        <button value="cancel" class="btn-secondary">Cancel</button>
        <button value="confirm" class="btn-danger">Confirm</button>
      </div>
    </form>
  `
  dialog.querySelector(".subtitle").textContent = message
  const removeDismissibleBehavior = makeDialogDismissible(dialog, () => dialog.close("cancel"))
  dialog.addEventListener("close", () => {
    removeDismissibleBehavior()
    resolve(dialog.returnValue === "confirm")
    dialog.remove()
  }, { once: true })
  document.body.append(dialog)
  dialog.showModal()
})
