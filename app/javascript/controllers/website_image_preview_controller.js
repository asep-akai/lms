import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["illustration", "upload", "remove", "image", "label", "status"]
  static values = { illustrations: Object, uploaded: Object }

  connect() { this.refresh() }
  disconnect() { this.releaseUpload() }

  refresh() {
    this.releaseUpload()
    const removing = this.hasRemoveTarget && this.removeTarget.checked
    const file = this.uploadTarget.files[0]
    let preview = this.illustrationsValue[this.illustrationTarget.value]
    if (!removing && file) {
      if (!["image/jpeg", "image/png", "image/webp"].includes(file.type) || file.size > 5 * 1024 * 1024) {
        this.imageTarget.hidden = true
        this.labelTarget.textContent = "Selected upload cannot be previewed."
        this.statusTarget.textContent = "Choose a JPEG, PNG or WebP up to 5 MB."
        return
      }
      this.objectUrl = URL.createObjectURL(file)
      preview = { src: this.objectUrl, alt: "Preview of selected upload", label: `New upload (not saved): ${file.name}` }
    } else if (!removing && this.uploadedValue.src) {
      preview = this.uploadedValue
    }
    this.labelTarget.textContent = preview?.label || "No image selected. This section will be text-only."
    this.imageTarget.hidden = !preview
    this.statusTarget.textContent = preview ? "Loading image preview…" : ""
    if (preview) {
      this.imageTarget.alt = preview.alt || "Section image preview"
      this.imageTarget.src = preview.src
      if (this.imageTarget.complete && this.imageTarget.naturalWidth > 0) this.loaded()
    } else {
      this.imageTarget.removeAttribute("src")
    }
  }

  loaded() { this.statusTarget.textContent = "" }
  failed() { this.statusTarget.textContent = "Image preview could not load. Reload the page or choose another image." }
  releaseUpload() {
    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
    this.objectUrl = null
  }
}
