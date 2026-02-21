import { Controller } from "@hotwired/stimulus"

// 変換結果のコピー操作と通知表示を扱うコントローラー
export default class extends Controller {
  static targets = ["source", "button", "label"]

  // 結果テキストをクリップボードへコピーする
  async copy() {
    if (!this.hasSourceTarget) return

    const text = this.sourceTarget.textContent.trim()
    if (text.length === 0) return

    try {
      await navigator.clipboard.writeText(text)
      this.showSuccessFeedback()
    } catch (_error) {
      this.showFailureFeedback()
    }
  }

  // 案C: スケール + リング演出で成功を通知
  showSuccessFeedback() {
    if (!this.hasButtonTarget || !this.hasLabelTarget) return

    const button = this.buttonTarget
    const label = this.labelTarget
    const originalLabel = button.dataset.originalLabel || label.textContent.trim()
    const activeClasses = ["scale-105", "ring-4", "ring-blue-300", "bg-blue-600"]

    button.dataset.originalLabel = originalLabel
    button.classList.add("transition-all", "duration-200")
    label.textContent = "コピーしました！"
    button.classList.add(...activeClasses)

    clearTimeout(this.resetTimer)
    this.resetTimer = setTimeout(() => {
      label.textContent = originalLabel
      button.classList.remove(...activeClasses)
    }, 2000)
  }

  // 失敗時は短く文言だけ戻す
  showFailureFeedback() {
    if (!this.hasButtonTarget || !this.hasLabelTarget) return

    const button = this.buttonTarget
    const label = this.labelTarget
    const originalLabel = button.dataset.originalLabel || label.textContent.trim()
    button.dataset.originalLabel = originalLabel
    label.textContent = "コピー失敗"

    clearTimeout(this.resetTimer)
    this.resetTimer = setTimeout(() => {
      label.textContent = originalLabel
    }, 1600)
  }

  disconnect() {
    clearTimeout(this.resetTimer)
  }
}
