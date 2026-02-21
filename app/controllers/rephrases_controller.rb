# 言い換え画面の表示と作成処理の入口を提供するコントローラー
class RephrasesController < ApplicationController
  # 直近の検索履歴を表示する初期画面
  def index
    @search_logs = SearchLog.order(created_at: :desc).limit(10)
  end

  # 言い換え処理を実行し、結果と履歴をTurbo Streamで更新
  def create
    @search_log = build_search_log
    respond_with_rephrase
  rescue ActiveRecord::ActiveRecordError => e
    handle_create_error(e)
  end

  private

  # フォームから受け取る言い換え入力値
  def rephrase_params
    params.require(:rephrase).permit(:content, :scene, :target, :context)
  end

  # sceneをカテゴリとして扱い、存在しなければ作成してIDを返す
  def resolved_category_id
    scene = rephrase_params[:scene].to_s.strip
    return Category.first_or_create!(name: "default").id if scene.blank?

    if scene.match?(/\A\d+\z/) && Category.exists?(scene.to_i)
      scene.to_i
    else
      Category.find_or_create_by!(name: scene).id
    end
  end

  # 言い換え結果をもとにSearchLogを作成
  def build_search_log
    category_id = resolved_category_id
    result = PhraseConverterService.call(query: rephrase_params[:content], category_id: category_id)

    SearchLog.create!(
      query: rephrase_params[:content],
      converted_text: result[:result_text],
      category_id: category_id,
      **result.slice(:hit_type, :safety_mode_applied)
    )
  end

  # Turbo Stream と通常HTMLのレスポンスを切り替え
  def respond_with_rephrase
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to rephrases_path }
    end
  end

  # DB接続や保存失敗などの異常時レスポンス
  def handle_create_error(error)
    Rails.logger.error("[rephrase#create] DBエラー: #{error.class} - #{error.message}")
    @error_message = "データベース接続に失敗しました。時間をおいて再試行してください。"

    respond_to do |format|
      format.turbo_stream { render :error, status: :service_unavailable }
      format.html { redirect_to rephrases_path, alert: @error_message }
    end
  end
end
