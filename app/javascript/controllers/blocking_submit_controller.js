import { Controller } from "@hotwired/stimulus"

let nextDialogId = 0

export default class extends Controller {
  connect() {
    nextDialogId += 1
    const titleId = `blocking-submit-title-${nextDialogId}`
    this.dialog = document.createElement("dialog")
    this.dialog.className = "blocking-dialog"
    this.dialog.setAttribute("aria-labelledby", titleId)
    this.dialog.innerHTML = `
      <div class="blocking-panel" role="status" aria-live="assertive">
        <div class="loading-spinner" aria-hidden="true"></div>
        <p class="eyebrow">Automatic grading</p>
        <h2 id="${titleId}" class="mt-1">Scoring and analyzing…</h2>
        <p class="mt-2 text-sm text-slate-600">Comparing answers and preparing feedback. Keep this page open.</p>
      </div>
    `
    this.preventCancel = (event) => event.preventDefault()
    this.dialog.addEventListener("cancel", this.preventCancel)
    this.element.append(this.dialog)
  }

  disconnect() {
    this.release()
    this.dialog?.removeEventListener("cancel", this.preventCancel)
  }

  start(event) {
    if (event.target !== this.element) return

    this.element.setAttribute("aria-busy", "true")
    document.documentElement.classList.add("overflow-hidden")
    this.dialog.showModal()
    console.info("[Automatic grading] Request started", { action: this.element.action })
  }

  finish(event) {
    if (event.target !== this.element) return

    console.info("[Automatic grading] Request finished", {
      action: this.element.action,
      success: event.detail.success
    })
    this.release()
  }

  release() {
    this.element.removeAttribute("aria-busy")
    document.documentElement.classList.remove("overflow-hidden")
    this.dialog?.close()
  }
}
