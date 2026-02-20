import { Controller } from "@hotwired/stimulus"

// 入力フォームの補助操作（クリア）を扱うコントローラー
export default class extends Controller {
  static targets = ["content"]

  // 原文テキストエリアだけをクリアする
  clearContent() {
    if (!this.hasContentTarget) return

    this.contentTarget.value = ""
    this.contentTarget.focus()
  }
}
