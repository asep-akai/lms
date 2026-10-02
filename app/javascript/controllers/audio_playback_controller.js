import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["player", "error", "download"]

  connect() {
    if (this.playerTarget.error) this.failed()
  }

  failed() {
    this.errorTarget.hidden = false
  }

  reset() {
    this.errorTarget.hidden = true
    const source = this.playerTarget.getAttribute("src")
    const localPreview = source?.startsWith("blob:")
    const url = localPreview ? source : this.downloadTarget.dataset.savedUrl
    this.downloadTarget.hidden = !url
    if (url) this.downloadTarget.href = url
    if (localPreview) {
      this.downloadTarget.download = this.element.querySelector("input[type='file']")?.files[0]?.name || "audio-response"
    } else {
      this.downloadTarget.removeAttribute("download")
    }
  }
}
