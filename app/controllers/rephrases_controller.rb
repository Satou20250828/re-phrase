# 言い換え画面の表示と作成処理の入口を提供するコントローラー
class RephrasesController < ApplicationController
  # 直近の検索履歴を表示する初期画面
  def index
    @search_logs = SearchLog.order(created_at: :desc).limit(10)
  end

  # create実装前の仮ハンドラ
  def create
    head :ok
  end
end
