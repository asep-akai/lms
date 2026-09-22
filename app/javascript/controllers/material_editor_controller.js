import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["blocks", "block", "position", "destroy", "textTemplate", "imageTemplate", "videoTemplate"]

  connect() {
    this.updatePositions()
  }

  addText() {
    this.addFrom(this.textTemplateTarget)
  }

  addImage() {
    this.addFrom(this.imageTemplateTarget)
  }

  addVideo() {
    this.addFrom(this.videoTemplateTarget)
  }

  moveUp(event) {
    const block = event.currentTarget.closest("[data-material-editor-target='block']")
    const blocks = this.visibleBlocks()
    const previous = blocks.at(blocks.indexOf(block) - 1)
    if (previous) this.blocksTarget.insertBefore(block, previous)
    this.updatePositions()
  }

  moveDown(event) {
    const block = event.currentTarget.closest("[data-material-editor-target='block']")
    const blocks = this.visibleBlocks()
    const next = blocks.at(blocks.indexOf(block) + 1)
    if (next) this.blocksTarget.insertBefore(next, block)
    this.updatePositions()
  }

  remove(event) {
    const block = event.currentTarget.closest("[data-material-editor-target='block']")
    block.querySelector("[data-material-editor-target='destroy']").value = "1"
    block.hidden = true
    this.updatePositions()
  }

  synchronize() {
    this.element.querySelectorAll("[data-controller~='rich-text-editor']").forEach((element) => {
      element.dispatchEvent(new CustomEvent("rich-text-editor:synchronize"))
    })
    this.updatePositions()
  }

  addFrom(template) {
    const identifier = `${Date.now()}${Math.floor(Math.random() * 1000)}`
    this.blocksTarget.insertAdjacentHTML("beforeend", template.innerHTML.replaceAll("NEW_BLOCK", identifier))
    this.updatePositions()
    this.blockTargets.at(-1)?.querySelector("[contenteditable], input[type='file'], input[type='url']")?.focus()
  }

  visibleBlocks() {
    return this.blockTargets.filter((block) => !block.hidden)
  }

  updatePositions() {
    const blocks = this.visibleBlocks()
    blocks.forEach((block, index) => {
      block.querySelector("[data-material-editor-target='position']").value = index + 1
      const up = block.querySelector("[data-action$='material-editor#moveUp']")
      const down = block.querySelector("[data-action$='material-editor#moveDown']")
      up.disabled = index === 0
      down.disabled = index === blocks.length - 1
    })
  }
}
