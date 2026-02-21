import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "rephrase_history"
const MAX_HISTORY_ITEMS = 30

export default class extends Controller {
  connect() {
    this.hydrateFromStorage()
    this.trimRenderedItems()

    this.observer = new MutationObserver((mutations) => {
      this.handleMutations(mutations)
    })

    this.observer.observe(this.listElement, {
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

  async deleteItem(event) {
    event.preventDefault()

    const itemNode = event.currentTarget.closest(".history-item")
    if (!itemNode) return

    const item = this.extractTextData(itemNode)
    if (item) this.removeFromStorage(item)

    const deleteUrl = itemNode.dataset.deleteUrl
    if (deleteUrl) await this.sendDeleteRequest(deleteUrl)

    itemNode.remove()
    this.trimRenderedItems()
  }

  async clearAll(event) {
    event.preventDefault()
    if (!window.confirm("履歴をすべて削除します。よろしいですか？")) return

    localStorage.removeItem(STORAGE_KEY)
    this.listElement.querySelectorAll(".history-item").forEach((node) => node.remove())

    const clearUrl = event.currentTarget.dataset.clearUrl
    if (clearUrl) {
      await this.sendDeleteRequest(clearUrl)
      return
    }

    const nodesWithUrl = Array.from(this.listElement.querySelectorAll(".history-item[data-delete-url]"))
    await Promise.all(nodesWithUrl.map((node) => this.sendDeleteRequest(node.dataset.deleteUrl)))
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

    this.trimRenderedItems()
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

  removeFromStorage(item) {
    const history = this.readHistory().filter((entry) => {
      return !(entry.originalText === item.originalText && entry.rephrasedText === item.rephrasedText)
    })

    localStorage.setItem(STORAGE_KEY, JSON.stringify(history.slice(0, MAX_HISTORY_ITEMS)))
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

  hydrateFromStorage() {
    const history = this.readHistory()
    if (history.length === 0) return

    const existingRephrased = new Set(this.currentRephrasedTexts())

    history.forEach((item) => {
      if (!item || typeof item !== "object") return
      if (!item.originalText || !item.rephrasedText) return

      this.expandStoredRephrasedTexts(item.rephrasedText).forEach((rephrasedText) => {
        if (existingRephrased.has(rephrasedText)) return

      this.listElement.appendChild(this.buildHistoryItemElement({
          originalText: item.originalText,
          rephrasedText: rephrasedText
        }))
        existingRephrased.add(rephrasedText)
      })
    })
  }

  expandStoredRephrasedTexts(rephrasedText) {
    const text = (rephrasedText || "").trim()
    if (!text) return []

    if (!/^\s*\d+[.)]?\s+/.test(text)) return [text]

    return text.split(/\n?\s*\d+[.)]?\s*/).map((item) => item.trim()).filter((item) => item.length > 0)
  }

  currentRephrasedTexts() {
    return Array.from(this.listElement.querySelectorAll(".rephrased-text")).map((node) => {
      return node.textContent?.trim() || ""
    }).filter((text) => text.length > 0)
  }

  buildHistoryItemElement(item) {
    const article = document.createElement("article")
    article.className = "history-item flex items-center justify-between p-3 bg-white rounded-xl border border-slate-100"

    const body = document.createElement("div")
    body.className = "flex-1 min-w-0 pr-4"

    const meta = document.createElement("div")
    meta.className = "flex items-center gap-2 mb-1"
    const metaText = document.createElement("span")
    metaText.className = "text-[10px] text-slate-400"
    metaText.textContent = "保存済み"
    meta.appendChild(metaText)

    const original = document.createElement("p")
    original.className = "original-text text-xs text-slate-600 truncate"
    original.textContent = item.originalText

    const rephrased = document.createElement("p")
    rephrased.className = "rephrased-text mt-1 text-xs text-slate-500 line-clamp-2"
    rephrased.textContent = item.rephrasedText

    body.appendChild(meta)
    body.appendChild(original)
    body.appendChild(rephrased)

    const actions = document.createElement("div")
    actions.className = "flex items-center gap-1 shrink-0"
    const button = document.createElement("button")
    button.type = "button"
    button.className = "p-1.5 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-all"
    button.dataset.action = "click->history#deleteItem"
    const icon = document.createElement("span")
    icon.className = "material-icons text-sm"
    icon.textContent = "delete"
    button.appendChild(icon)
    actions.appendChild(button)

    article.appendChild(body)
    article.appendChild(actions)
    return article
  }

  trimRenderedItems() {
    const items = Array.from(this.listElement.querySelectorAll(".history-item"))
    if (items.length <= MAX_HISTORY_ITEMS) return

    items.slice(MAX_HISTORY_ITEMS).forEach((node) => node.remove())
  }

  get listElement() {
    if (this.element.id === "history_list") return this.element

    return this.element.querySelector("#history_list") || this.element
  }

  requestHeaders() {
    const token = document.querySelector("meta[name='csrf-token']")?.content

    return {
      "X-CSRF-Token": token || "",
      Accept: "application/json"
    }
  }

  async sendDeleteRequest(url) {
    if (!url) return

    try {
      await fetch(url, {
        method: "DELETE",
        headers: this.requestHeaders(),
        credentials: "same-origin"
      })
    } catch (_error) {
      // ネットワーク失敗時もUI操作を継続させる
    }
  }
}
