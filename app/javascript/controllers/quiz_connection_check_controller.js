import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { makeDialogDismissible } from "dialog"

const checkedQuizKeys = new Set()
const WARMUP_PROBES = 1
const MEASURED_PROBES = 4
const SAMPLE_TIMEOUT_MS = 3000
const PROBE_PAUSE_MS = 120
const MINIMUM_BENCHMARK_MS = 5000
const CIRCLE_CIRCUMFERENCE = 2 * Math.PI * 72

export default class extends Controller {
  static targets = [
    "dialog", "testing", "result", "statusLabel", "title", "summary",
    "latency", "jitter", "downloadSpeed", "networkType", "proceed", "retry",
    "progressCircle", "progressBar", "progressText", "phase", "probeLabel",
    "liveLatency", "liveSpeed"
  ]

  static values = { testUrl: String, storageKey: String, confirm: String }

  connect() {
    this.removeDismissibleBehavior = makeDialogDismissible(this.dialogTarget, () => this.close())
  }

  disconnect() {
    this.removeDismissibleBehavior?.()
    this.releasePage()
  }

  async check(event) {
    if (this.proceeding) {
      this.proceeding = false
      return
    }

    if (event.currentTarget.tagName === "FORM") {
      event.preventDefault()
      this.form = event.currentTarget
      this.destination = null
      if (this.confirmValue && !await Turbo.config.forms.confirm(this.confirmValue)) return
      if (this.wasChecked()) {
        this.submitForm()
        return
      }
    } else {
      if (this.wasChecked()) return

      event.preventDefault()
      this.form = null
      this.destination = event.currentTarget.href
    }
    document.documentElement.classList.add("overflow-hidden")
    this.dialogTarget.showModal()
    await this.runBenchmark()
  }

  async retry() {
    if (this.testing) return

    await this.runBenchmark()
  }

  async runBenchmark() {
    this.testing = true
    this.showTestingState()

    const startedAt = performance.now()
    const result = await this.measureConnection()
    const remainingDuration = MINIMUM_BENCHMARK_MS - (performance.now() - startedAt)
    this.updateProgress(95, "Completing the five-second benchmark…", "Final check")
    if (remainingDuration > 0) await this.pause(remainingDuration)
    this.updateProgress(100, "Benchmark complete.", "Complete")
    if (result.quality === "optimal") this.markPassed()
    this.testing = false
    this.showResult(result)
  }

  proceed() {
    const destination = this.destination
    this.close()
    if (this.form) {
      this.submitForm()
    } else {
      Turbo.visit(destination)
    }
  }

  submitForm() {
    this.proceeding = true
    this.form.requestSubmit()
  }

  close() {
    if (this.testing) return

    this.dialogTarget.close()
    this.releasePage()
  }

  showTestingState() {
    this.testingTarget.hidden = false
    this.resultTarget.hidden = true
    this.progressCircleTarget.style.strokeDasharray = CIRCLE_CIRCUMFERENCE
    this.updateProgress(0, "Preparing the speed test.", "Warm-up probe")
    this.liveLatencyTarget.textContent = "—"
    this.liveSpeedTarget.textContent = "—"
  }

  async measureConnection() {
    const totalProbes = WARMUP_PROBES + MEASURED_PROBES
    const measurementProgress = 90
    const latencies = []
    const downloadSpeeds = []

    for (let index = 0; index < totalProbes; index += 1) {
      const warmup = index < WARMUP_PROBES
      const displayNumber = warmup ? null : index - WARMUP_PROBES + 1
      const label = warmup ? "Warm-up probe" : `Measured probe ${displayNumber} of ${MEASURED_PROBES}`
      const baseProgress = (index / totalProbes) * measurementProgress

      this.updateProgress(baseProgress, "Measuring server response time…", label)
      const latency = await this.measureLatency().catch(() => null)
      if (latency !== null) {
        this.liveLatencyTarget.textContent = `${Math.round(latency)} ms`
        if (!warmup) latencies.push(latency)
      }

      this.updateProgress(baseProgress + (measurementProgress / 2 / totalProbes), "Downloading a 128 KB benchmark payload…", label)
      const speed = await this.measureDownloadSpeed().catch(() => null)
      if (speed !== null) {
        this.liveSpeedTarget.textContent = this.formatSpeed(speed)
        if (!warmup) downloadSpeeds.push(speed)
      }

      this.updateProgress(((index + 1) / totalProbes) * measurementProgress, "Processing benchmark sample…", label)
      await this.pause(PROBE_PAUSE_MS)
    }

    const latency = this.median(latencies)
    const downloadMbps = this.median(downloadSpeeds)
    const jitter = latency === null || latencies.length < 2 ? null :
      latencies.reduce((total, sample) => total + Math.abs(sample - latency), 0) / latencies.length
    const connection = navigator.connection || navigator.mozConnection || navigator.webkitConnection
    const warnings = []

    if (!navigator.onLine) warnings.push("Your browser reports that it is offline.")
    if (latency === null) warnings.push("The app could not reach the server during the test.")
    if (downloadMbps === null) warnings.push("Download speed could not be measured.")
    if (latency !== null && latency >= 250) warnings.push(`Latency is above the optimal 250 ms target (${Math.round(latency)} ms).`)
    if (downloadMbps !== null && downloadMbps < 1.5) warnings.push(`Download speed is below the optimal 1.5 Mbps target (${this.formatSpeed(downloadMbps)}).`)
    if (jitter !== null && jitter >= 50) warnings.push(`Connection timing is inconsistent (${Math.round(jitter)} ms jitter).`)
    if ([ "slow-2g", "2g" ].includes(connection?.effectiveType)) warnings.push("Your browser reports a slow mobile connection.")
    if (connection?.saveData) warnings.push("Data Saver is enabled and may affect uploads.")

    const unstable = latency === null || downloadMbps === null || latency >= 600 || downloadMbps < 0.25
    const quality = warnings.length === 0 ? "optimal" : unstable ? "unstable" : "stable"
    return { latency, jitter, downloadMbps, connection, warnings, quality }
  }

  async measureLatency() {
    const startedAt = performance.now()
    await this.fetchProbe("latency")
    return performance.now() - startedAt
  }

  async measureDownloadSpeed() {
    const startedAt = performance.now()
    const payload = await this.fetchProbe("download", true)
    const elapsedSeconds = Math.max((performance.now() - startedAt) / 1000, 0.001)
    return (payload.byteLength * 8) / elapsedSeconds / 1_000_000
  }

  async fetchProbe(probe, readBody = false) {
    const controller = new AbortController()
    const timeout = window.setTimeout(() => controller.abort(), SAMPLE_TIMEOUT_MS)

    try {
      const separator = this.testUrlValue.includes("?") ? "&" : "?"
      const response = await fetch(`${this.testUrlValue}${separator}probe=${probe}&sample=${this.sampleId()}`, {
        cache: "no-store",
        credentials: "same-origin",
        headers: { "X-Connection-Test": "1" },
        signal: controller.signal
      })
      if (!response.ok) throw new Error(`Connection test returned ${response.status}`)

      return readBody ? await response.arrayBuffer() : response
    } finally {
      window.clearTimeout(timeout)
    }
  }

  showResult({ latency, jitter, downloadMbps, connection, warnings, quality }) {
    const warning = quality !== "optimal"
    this.testingTarget.hidden = true
    this.resultTarget.hidden = false
    this.statusLabelTarget.className = warning ? "badge-suspended" : "badge-active"
    this.statusLabelTarget.textContent = warning ? "Connection warning" : "Connection ready"
    this.titleTarget.textContent = quality === "unstable" ? "Your connection may be unstable" :
      warning ? "Your connection is usable, but not optimal" : "Your connection looks good"
    this.summaryTarget.textContent = warning ?
      `${warnings.join(" ")} You can still continue, but the benchmark will run again next time until your connection passes.` :
      "The app responded normally. You can begin the quiz."
    this.latencyTarget.textContent = latency === null ? "Unavailable" : `${Math.round(latency)} ms`
    this.jitterTarget.textContent = jitter === null ? "Unavailable" : `${Math.round(jitter)} ms`
    this.downloadSpeedTarget.textContent = downloadMbps === null ? "Unavailable" : this.formatSpeed(downloadMbps)
    this.networkTypeTarget.textContent = `${quality.charAt(0).toUpperCase()}${quality.slice(1)}${connection?.effectiveType ? ` · ${connection.effectiveType.toUpperCase()}` : ""}`
    this.proceedTarget.textContent = warning ? "Proceed anyway" : "Continue to quiz"
    this.proceedTarget.className = warning ? "btn-secondary" : "btn-primary"
    this.retryTarget.hidden = !warning
    if (warning) {
      this.retryTarget.focus()
    } else {
      this.proceedTarget.focus()
    }
  }

  updateProgress(progress, phase, probeLabel) {
    const boundedProgress = Math.max(0, Math.min(100, progress))
    this.progressCircleTarget.style.strokeDashoffset = CIRCLE_CIRCUMFERENCE * (1 - boundedProgress / 100)
    this.progressBarTarget.style.width = `${boundedProgress}%`
    this.progressTextTarget.textContent = `${Math.round(boundedProgress)}%`
    this.phaseTarget.textContent = phase
    this.probeLabelTarget.textContent = probeLabel
  }

  median(values) {
    if (values.length === 0) return null

    const sorted = [ ...values ].sort((left, right) => left - right)
    const middle = Math.floor(sorted.length / 2)
    return sorted.length % 2 === 0 ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
  }

  formatSpeed(mbps) {
    if (mbps >= 1000) return `${(mbps / 1000).toFixed(1)} Gbps`
    return mbps >= 1 ? `${mbps.toFixed(1)} Mbps` : `${Math.round(mbps * 1000)} Kbps`
  }

  sampleId() {
    if (typeof globalThis.crypto?.randomUUID === "function") return globalThis.crypto.randomUUID()

    return `${Date.now()}-${Math.random().toString(36).slice(2)}`
  }

  pause(milliseconds) {
    return new Promise((resolve) => window.setTimeout(resolve, milliseconds))
  }

  wasChecked() {
    if (checkedQuizKeys.has(this.storageKeyValue)) return true

    try {
      return sessionStorage.getItem(this.storageKeyValue) === "passed"
    } catch (_error) {
      return false
    }
  }

  markPassed() {
    checkedQuizKeys.add(this.storageKeyValue)
    try {
      sessionStorage.setItem(this.storageKeyValue, "passed")
    } catch (_error) {
      // The in-memory set still prevents a repeated check on this page.
    }
  }

  releasePage() {
    document.documentElement.classList.remove("overflow-hidden")
  }
}
