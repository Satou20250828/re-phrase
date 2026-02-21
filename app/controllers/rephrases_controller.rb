# 言い換え画面の表示と作成処理の入口を提供するコントローラー
class RephrasesController < ApplicationController
  # 直近の検索履歴を表示する初期画面
  def index
    @search_logs = SearchLog.order(created_at: :desc).limit(10)
    @rephrased_results = fetch_recent_rephrases
  rescue StandardError => e
    Rails.logger.error("[rephrase#index] エラー: #{e.class} - #{e.message}")
    @search_logs = []
    @rephrased_results = []
  end

  # 言い換え処理を実行し、結果と履歴をTurbo Streamで更新
  def create
    @search_log = nil
    @db_warning_message = nil
    result = safe_convert_result(rephrase_params[:content])
    result_text = result[:result_text].to_s

    begin
      @search_log = build_search_log_with(result)
      @rephrased_results = fetch_recent_rephrases
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.error("[rephrase#create] DB保存失敗: #{e.class} - #{e.message}")
      @db_warning_message = "データベース接続に失敗したため、結果は一時表示のみです。"
      @rephrased_results = [Rephrase.new(content: result_text)]
    end

    respond_with_rephrase
  rescue StandardError => e
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
  def build_search_log_with(result)
    category_id = resolved_category_id
    Rephrase.create!(content: result[:result_text], category_id: category_id)

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

  # 予期しない失敗時のレスポンス
  def handle_create_error(error)
    Rails.logger.error("[rephrase#create] エラー: #{error.class} - #{error.message}")
    @error_message = "言い換え処理に失敗しました。入力内容を確認して再試行してください。"
    @rephrased_results = []
    @search_log = nil

    respond_to do |format|
      format.turbo_stream { render :error, status: :service_unavailable }
      format.html { redirect_to rephrases_path, alert: @error_message }
    end
  end

  # DB接続不可でも画面確認を継続できるように言い換え結果をフォールバックする
  def safe_convert_result(content)
    PhraseConverterService.call(query: content, category_id: nil)
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.warn("[rephrase#create] 変換時DB参照に失敗: #{e.class} - #{e.message}")
    {
      result_text: content.to_s,
      safety_mode_applied: true,
      hit_type: :none
    }
  end

  # 画面表示用に最新の言い換え結果を取得する
  def fetch_recent_rephrases
    Rephrase.order(created_at: :desc).limit(3).to_a
  rescue ActiveRecord::ActiveRecordError
    []
  end
end
