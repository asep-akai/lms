import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "start", "stop", "retry", "status", "duration", "visualizer"]

  connect() {
    this.chunks = []
    this.recordingSeconds = 0
    this.showReadyState(this.previewTarget.getAttribute("src")?.length > 0)
  }

  disconnect() {
    this.stopTimer()
    this.stopVisualizer()
    this.releaseStream()
    this.revokePreviewUrl()
  }

  async start() {
    if (!navigator.mediaDevices?.getUserMedia || !window.MediaRecorder) {
      this.showError("Recording is not supported in this browser. Upload a compatible audio file instead.")
      return
    }

    const mimeType = this.supportedMimeType()
    if (!mimeType) {
      this.showError("This browser cannot record a Gemini-compatible format. Upload a compatible audio file instead.")
      return
    }

    this.startTarget.disabled = true
    this.retryTarget.disabled = true
    this.statusTarget.textContent = "Waiting for microphone access…"

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      this.mimeType = mimeType
      this.chunks = []
      this.mediaRecorder = new MediaRecorder(this.stream, { mimeType })
      this.mediaRecorder.addEventListener("dataavailable", (event) => {
        if (event.data.size > 0) this.chunks.push(event.data)
      })
      this.mediaRecorder.addEventListener("stop", () => this.completeRecording(), { once: true })
      this.mediaRecorder.addEventListener("error", () => this.showError("The recording failed. Try again or upload an audio file."), { once: true })
      this.mediaRecorder.start()
      this.showRecordingState()
      this.startVisualizer()
    } catch (error) {
      this.releaseStream()
      const message = error?.name === "NotAllowedError"
        ? "Microphone access was denied. Allow access or upload an audio file instead."
        : "The microphone could not be opened. Try again or upload an audio file."
      this.showError(message)
    }
  }

  stop() {
    if (this.mediaRecorder?.state === "recording") this.mediaRecorder.stop()
  }

  retry() {
    this.start()
  }

  fileSelected() {
    const file = this.inputTarget.files[0]
    if (!file) return

    this.setPreview(file)
    this.statusTarget.textContent = `${file.name} is ready. It will replace any previously saved recording when you continue.`
    this.showReadyState(true)
  }

  supportedMimeType() {
    if (typeof MediaRecorder.isTypeSupported !== "function") return "audio/mp4"

    return [
      "audio/webm;codecs=opus",
      "audio/webm",
      "audio/ogg;codecs=opus",
      "audio/ogg",
      "audio/mp4",
      "audio/mp4;codecs=mp4a.40.2"
    ].find((type) => MediaRecorder.isTypeSupported(type))
  }

  showRecordingState() {
    this.startTarget.hidden = true
    this.retryTarget.hidden = true
    this.stopTarget.hidden = false
    this.stopTarget.disabled = false
    this.recordingSeconds = 0
    this.durationTarget.textContent = "00:00"
    this.durationTarget.hidden = false
    this.visualizerTarget.hidden = false
    this.statusTarget.textContent = "Recording…"
    this.timer = window.setInterval(() => {
      this.recordingSeconds += 1
      this.durationTarget.textContent = this.formattedDuration(this.recordingSeconds)
    }, 1000)
  }

  showReadyState(hasAudio) {
    this.startTarget.hidden = hasAudio
    this.startTarget.disabled = false
    this.retryTarget.hidden = !hasAudio
    this.retryTarget.disabled = false
    this.stopTarget.hidden = true
    this.stopTarget.disabled = true
    this.durationTarget.hidden = true
    this.visualizerTarget.hidden = true
  }

  showError(message) {
    this.stopTimer()
    this.stopVisualizer()
    this.releaseStream()
    this.statusTarget.textContent = message
    this.showReadyState(this.previewTarget.getAttribute("src")?.length > 0)
  }

  completeRecording() {
    this.stopTimer()
    this.stopVisualizer()
    this.releaseStream()

    if (this.chunks.length === 0) {
      this.showError("No audio was captured. Try recording again.")
      return
    }

    const recordedType = this.chunks.find((chunk) => chunk.type)?.type || this.mediaRecorder?.mimeType || this.mimeType
    const contentType = recordedType.split(";")[0]
    const extension = {
      "audio/ogg": "ogg",
      "audio/mp4": "m4a",
      "video/mp4": "m4a"
    }[contentType] || "webm"
    const blob = new Blob(this.chunks, { type: contentType })
    const file = new File([blob], `recording-${Date.now()}.${extension}`, { type: contentType })

    try {
      const transfer = new DataTransfer()
      transfer.items.add(file)
      this.inputTarget.files = transfer.files
      this.setPreview(file)
      this.statusTarget.textContent = "Recording ready. Record again to replace it, or continue to save it."
      this.showReadyState(true)
    } catch (_error) {
      this.showError("This browser could not attach the recording. Downloading is unavailable, so upload a compatible audio file instead.")
    }
  }

  setPreview(file) {
    this.revokePreviewUrl()
    this.previewUrl = URL.createObjectURL(file)
    this.previewTarget.src = this.previewUrl
    this.previewTarget.hidden = false
    this.previewTarget.load()
  }

  formattedDuration(seconds) {
    const minutes = Math.floor(seconds / 60).toString().padStart(2, "0")
    const remainder = (seconds % 60).toString().padStart(2, "0")
    return `${minutes}:${remainder}`
  }

  stopTimer() {
    if (this.timer) window.clearInterval(this.timer)
    this.timer = null
  }

  async startVisualizer() {
    this.drawSilentVisualizer()
    const AudioContextClass = window.AudioContext || window.webkitAudioContext
    if (!AudioContextClass) return

    try {
      this.audioContext = new AudioContextClass()
      await this.audioContext.resume()
      this.analyser = this.audioContext.createAnalyser()
      this.analyser.fftSize = 256
      this.audioSource = this.audioContext.createMediaStreamSource(this.stream)
      this.audioSource.connect(this.analyser)
      this.waveform = new Uint8Array(this.analyser.frequencyBinCount)
      this.drawVisualizer()
    } catch (_error) {
      this.drawSilentVisualizer()
    }
  }

  drawVisualizer() {
    if (!this.analyser) return

    this.analyser.getByteTimeDomainData(this.waveform)
    const { context, width, height } = this.visualizerContext()
    context.fillStyle = "#f8fafc"
    context.fillRect(0, 0, width, height)
    context.strokeStyle = "#4338ca"
    context.lineWidth = Math.max(2, window.devicePixelRatio || 1)
    context.beginPath()

    const sliceWidth = width / this.waveform.length
    this.waveform.forEach((value, index) => {
      const x = index * sliceWidth
      const y = (value / 255) * height
      index === 0 ? context.moveTo(x, y) : context.lineTo(x, y)
    })
    context.stroke()
    this.visualizerFrame = window.requestAnimationFrame(() => this.drawVisualizer())
  }

  drawSilentVisualizer() {
    const { context, width, height } = this.visualizerContext()
    context.fillStyle = "#f8fafc"
    context.fillRect(0, 0, width, height)
    context.strokeStyle = "#94a3b8"
    context.lineWidth = Math.max(2, window.devicePixelRatio || 1)
    context.beginPath()
    context.moveTo(0, height / 2)
    context.lineTo(width, height / 2)
    context.stroke()
  }

  visualizerContext() {
    const ratio = window.devicePixelRatio || 1
    const width = Math.max(this.visualizerTarget.clientWidth, 320) * ratio
    const height = 96 * ratio
    if (this.visualizerTarget.width !== width) this.visualizerTarget.width = width
    if (this.visualizerTarget.height !== height) this.visualizerTarget.height = height
    return { context: this.visualizerTarget.getContext("2d"), width, height }
  }

  stopVisualizer() {
    if (this.visualizerFrame) window.cancelAnimationFrame(this.visualizerFrame)
    this.visualizerFrame = null
    this.audioSource?.disconnect()
    this.audioSource = null
    this.analyser = null
    this.audioContext?.close()
    this.audioContext = null
  }

  releaseStream() {
    this.stream?.getTracks().forEach((track) => track.stop())
    this.stream = null
  }

  revokePreviewUrl() {
    if (this.previewUrl) URL.revokeObjectURL(this.previewUrl)
    this.previewUrl = null
  }
}
