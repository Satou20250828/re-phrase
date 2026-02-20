import { Controller } from "@hotwired/stimulus"

// 変換結果のコピー操作と通知表示を扱うコントローラー
export default class extends Controller {
  static targets = ["source", "feedback", "button"]

  // 結果テキストをクリップボードへコピーする
  async copy() {
    if (!this.hasSourceTarget) return

    const text = this.sourceTarget.textContent.trim()
    if (text.length === 0) return

    try {
      await navigator.clipboard.writeText(text)
      this.showFeedback("コピーしました")
    } catch (_error) {
      this.showFeedback("コピーに失敗しました")
    }
  }

  // コピー結果を短時間表示し、元の表示へ戻す
  showFeedback(message) {
    if (this.hasFeedbackTarget) {
      this.feedbackTarget.textContent = message
      this.feedbackTarget.classList.remove("hidden")
      setTimeout(() => this.feedbackTarget.classList.add("hidden"), 1800)
    }

    if (this.hasButtonTarget) {
      const original = this.buttonTarget.dataset.originalLabel || this.buttonTarget.textContent
      this.buttonTarget.dataset.originalLabel = original
      this.buttonTarget.textContent = message
      setTimeout(() => {
        this.buttonTarget.textContent = original
      }, 1800)
    }
  }
}
