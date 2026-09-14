export function makeDialogDismissible(dialog, dismiss) {
  dialog.classList.add("dismissible-modal")

  const handleClick = (event) => {
    if (event.target !== dialog) return

    const bounds = dialog.getBoundingClientRect()
    const insideDialog = event.clientX >= bounds.left && event.clientX <= bounds.right &&
      event.clientY >= bounds.top && event.clientY <= bounds.bottom

    if (!insideDialog) dismiss(event)
  }

  const handleCancel = (event) => {
    event.preventDefault()
    dismiss(event)
  }

  dialog.addEventListener("click", handleClick)
  dialog.addEventListener("cancel", handleCancel)

  return () => {
    dialog.removeEventListener("click", handleClick)
    dialog.removeEventListener("cancel", handleCancel)
  }
}
