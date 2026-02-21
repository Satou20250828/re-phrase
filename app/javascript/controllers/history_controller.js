import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "rephrase_history"
const MAX_HISTORY_ITEMS = 30

export default class extends Controller {
  connect() {
    this.observer = new MutationObserver((mutations) => {
      this.handleMutations(mutations)
    })

    this.observer.observe(this.element, {
      childList: true,
      subtree: true
    })
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
      this.observer = null
    }
  }

  handleMutations(mutations) {
    mutations.forEach((mutation) => {
      mutation.addedNodes.forEach((node) => {
        if (!(node instanceof Element)) return

        this.extractHistoryItems(node).forEach((item) => {
          this.saveHistoryItem(item)
        })
      })
    })
  }

  extractHistoryItems(node) {
    const items = []

    if (node.matches(".history-item")) {
      const data = this.extractTextData(node)
      if (data) items.push(data)
    }

    node.querySelectorAll(".history-item").forEach((itemNode) => {
      const data = this.extractTextData(itemNode)
      if (data) items.push(data)
    })

    return items
  }

  extractTextData(itemNode) {
    const originalText = itemNode.querySelector(".original-text")?.textContent?.trim() || ""
    const rephrasedText = itemNode.querySelector(".rephrased-text")?.textContent?.trim() || ""

    if (!originalText || !rephrasedText) return null

    return { originalText, rephrasedText }
  }

  saveHistoryItem(item) {
    const history = this.readHistory()

    const isDuplicate = history.some((entry) => {
      return entry.originalText === item.originalText && entry.rephrasedText === item.rephrasedText
    })
    if (isDuplicate) return

    history.unshift(item)
    const truncated = history.slice(0, MAX_HISTORY_ITEMS)
    localStorage.setItem(STORAGE_KEY, JSON.stringify(truncated))
  }

  readHistory() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY)
      if (!raw) return []

      const parsed = JSON.parse(raw)
      return Array.isArray(parsed) ? parsed : []
    } catch (_error) {
      return []
    }
  }
}
