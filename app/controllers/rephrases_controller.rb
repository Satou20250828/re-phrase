# 言い換え画面の表示と作成処理の入口を提供するコントローラー
# rubocop:disable Metrics/ClassLength
class RephrasesController < ApplicationController
  DEFAULT_CATEGORY_NAME = "default".freeze
  MOCK_RESULT_TEXT = "【モック】お手伝いできます。状況をもう少し詳しく教えてください。".freeze
  MOCK_VARIATIONS = [
    "【モックA】ご連絡ありがとうございます。\n現状を確認し、対応方針を本日中に共有いたします。進捗は30分ごとに更新します。",
    "【モックB】恐れ入りますが、次の3点をご共有ください: 1) 発生時刻 2) 再現手順 3) 期待結果。#debug #rails",
    "【モックC】承知しました。\"至急対応\"として扱います。特殊文字テスト: !@#$%^&*()[]{}<>/\\|~`",
    "【モックD】結論: まず暫定回避を適用し、恒久対策は別PRで実施します。改行テスト\n- 影響範囲: 限定的\n- 優先度: 高"
  ].freeze

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
    prepare_create_context
    process_create_result(safe_convert_result(rephrase_params[:content]))
    return render_validation_errors if @rephrase&.errors&.any?

    respond_with_rephrase
  rescue StandardError => e
    handle_create_error(e)
  end

  def destroy_history
    search_log = SearchLog.find_by(id: params[:id])
    return head :not_found unless search_log

    search_log.destroy!
    head :no_content
  rescue StandardError => e
    Rails.logger.error("[rephrase#destroy_history] エラー: #{e.class} - #{e.message}")
    head :unprocessable_content
  end

  def clear_history
    SearchLog.order(created_at: :desc).destroy_all
    head :no_content
  rescue StandardError => e
    Rails.logger.error("[rephrase#clear_history] エラー: #{e.class} - #{e.message}")
    head :unprocessable_content
  end

  # Backward compatible endpoint for legacy request specs.
  def search
    query = params[:q].to_s
    result = PhraseConverterService.call(query: query, category_id: params[:category_id])
    save_search_log_compat(query: query, category_id: params[:category_id], result: result)

    render plain: result[:result_text].to_s, status: :ok
  rescue StandardError => e
    Rails.logger.error("[rephrase#search] エラー: #{e.class} - #{e.message}")
    render plain: query, status: :ok
  end

  private

  def save_search_log_compat(query:, category_id:, result:)
    SearchLog.create(
      query: query,
      converted_text: result[:result_text].to_s,
      category_id: category_id,
      hit_type: normalize_hit_type_value(result[:hit_type]),
      safety_mode_applied: ActiveModel::Type::Boolean.new.cast(result[:safety_mode_applied])
    )
  rescue StandardError => e
    Rails.logger.warn("[rephrase#search] SearchLog保存失敗: #{e.class} - #{e.message}")
  end

  # フォームから受け取る言い換え入力値
  def rephrase_params
    params.require(:rephrase).permit(:content, :scene, :target, :context)
  end

  # sceneをカテゴリとして扱い、存在しなければ作成してIDを返す
  def resolved_category
    scene = rephrase_params[:scene].to_s.strip
    return Category.find_or_create_by!(name: DEFAULT_CATEGORY_NAME) if scene.blank?

    if scene.match?(/\A\d+\z/)
      category = Category.find_by(id: scene.to_i)
      return category if category.present?
    end

    Category.find_or_create_by!(name: scene)
  end

  # 言い換え結果を分割し、各案をRephrase/SearchLogとして保存
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/BlockLength
  def build_search_logs_with(result)
    category = resolved_category
    normalized_result_text = normalized_result_text(result[:result_text])
    candidates = split_rephrase_candidates(normalized_result_text)
    normalized_hit_type = normalize_hit_type_value(result[:hit_type])
    created_search_logs = []

    ActiveRecord::Base.transaction do
      candidates.each do |candidate|
        @rephrase = Rephrase.new(content: candidate, category: category)
        unless @rephrase.save
          log_validation_failure(
            model_name: "Rephrase",
            errors: @rephrase.errors.full_messages,
            attributes: @rephrase.attributes.slice("content", "category_id")
          )
          raise ActiveRecord::RecordInvalid, @rephrase
        end

        @search_log = SearchLog.new(
          query: rephrase_params[:content].to_s.strip,
          converted_text: candidate,
          category: category,
          hit_type: normalized_hit_type,
          safety_mode_applied: ActiveModel::Type::Boolean.new.cast(result[:safety_mode_applied])
        )
        unless @search_log.save
          log_validation_failure(
            model_name: "SearchLog",
            errors: @search_log.errors.full_messages,
            attributes: @search_log.attributes.slice("query", "converted_text", "category_id", "hit_type",
                                                     "safety_mode_applied")
          )
          log_search_log_category_association(@search_log)
          raise ActiveRecord::RecordInvalid, @search_log
        end

        created_search_logs << @search_log
      end
    end

    created_search_logs
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/BlockLength

  def prepare_create_context
    @rephrase = nil
    @search_log = nil
    @search_logs = []
    @db_warning_message = nil
    @error_message = nil
    @field_errors = {}
  end

  def process_create_result(result)
    @search_logs = build_search_logs_with(result)
    cleanup_old_search_logs!
    @search_log = @search_logs.first
    @rephrased_results = fetch_recent_rephrases
  rescue ActiveRecord::ActiveRecordError => e
    handle_create_persistence_error(e, result)
  end

  def cleanup_old_search_logs!
    SearchLog.order(created_at: :desc).offset(30).destroy_all
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def handle_create_persistence_error(error, result)
    @field_errors = extract_field_errors(error)
    @error_message = build_user_error_message(error)

    log_rephrase_error("DB保存失敗", error, payload: {
                         input_content: rephrase_params[:content].to_s,
                         resolved_scene: rephrase_params[:scene].to_s,
                         input_target: rephrase_params[:target].to_s,
                         input_context: rephrase_params[:context].to_s,
                         result_preview: result[:result_text].to_s.truncate(80)
                       })
    @db_warning_message = "データベース接続に失敗したため、結果は一時表示のみです。"
    @rephrased_results = [Rephrase.new(content: result[:result_text].to_s)]
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def render_validation_errors
    @search_logs = SearchLog.order(created_at: :desc).limit(10)

    respond_to do |format|
      format.turbo_stream { render :index, status: :unprocessable_content, formats: [:html] }
      format.html { render :index, status: :unprocessable_content }
    end
  end

  # Turbo Stream と通常HTMLのレスポンスを切り替え
  def respond_with_rephrase
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to rephrases_path }
    end
  end

  # 予期しない失敗時のレスポンス
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def handle_create_error(error)
    log_rephrase_error("エラー", error, payload: {
                         input_content: rephrase_params[:content].to_s,
                         scene: rephrase_params[:scene].to_s,
                         target: rephrase_params[:target].to_s,
                         context: rephrase_params[:context].to_s
                       })
    @error_message = "言い換え処理に失敗しました。入力内容を確認して再試行してください。"
    @rephrased_results = []
    @search_log = nil
    @field_errors = extract_field_errors(error)

    respond_to do |format|
      format.turbo_stream { render :error, status: :service_unavailable }
      format.html { redirect_to rephrases_path, alert: @error_message }
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # DB接続不可でも画面確認を継続できるように言い換え結果をフォールバックする
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def safe_convert_result(content)
    if use_mock_conversion?
      Rails.logger.warn("[rephrase#create] mock conversion enabled. external api is bypassed.")
      return mock_convert_result(content)
    end

    PhraseConverterService.call(
      query: content,
      category_id: nil,
      scene: rephrase_params[:scene],
      target: rephrase_params[:target],
      context: rephrase_params[:context]
    )
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.warn("[rephrase#create] 変換時DB参照に失敗: #{e.class} - #{e.message}")
    {
      result_text: content.to_s,
      safety_mode_applied: true,
      hit_type: :none
    }
  rescue StandardError => e
    Rails.logger.error("[rephrase#create] 外部API呼び出し/変換処理に失敗: #{e.class} - #{e.message}")
    Rails.logger.error("[rephrase#create] converter_backtrace:\n#{Array(e.backtrace).first(20).join("\n")}")
    {
      result_text: content.to_s,
      safety_mode_applied: true,
      hit_type: :none
    }
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # 画面表示用に最新の言い換え結果を取得する
  def fetch_recent_rephrases
    Rephrase.order(created_at: :desc).limit(3).to_a
  rescue ActiveRecord::ActiveRecordError
    []
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def log_rephrase_error(label, error, payload: {})
    Rails.logger.error("[rephrase#create] #{label}: #{error.class} - #{error.message}")
    Rails.logger.error("[rephrase#create] payload: #{payload.inspect}") if payload.present?

    if error.respond_to?(:record) && error.record.respond_to?(:errors)
      record = error.record
      Rails.logger.error(
        "[rephrase#create] record_invalid model=#{record.class} " \
        "attributes=#{record.attributes.slice('id', 'content', 'category_id').inspect} " \
        "errors=#{record.errors.full_messages.join(', ')}"
      )
    end

    if error.is_a?(ActiveRecord::RecordInvalid)
      Rails.logger.error("[rephrase#create] full_messages: #{error.record.errors.full_messages.join(', ')}")
    end

    return unless error.respond_to?(:backtrace) && error.backtrace.present?

    Rails.logger.error("[rephrase#create] backtrace:\n#{error.backtrace.first(20).join("\n")}")
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def use_mock_conversion?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch("REPHRASE_USE_MOCK", false))
  end

  def mock_convert_result(content)
    text = content.to_s.strip
    base = MOCK_VARIATIONS.sample || MOCK_RESULT_TEXT
    rendered = text.present? ? "#{base}\n\n[入力原文] #{text}" : base

    {
      result_text: rendered,
      safety_mode_applied: true,
      hit_type: :none
    }
  end

  def normalized_result_text(raw_text)
    candidate = raw_text.to_s.strip
    return candidate if candidate.present?

    rephrase_params[:content].to_s
  end

  def split_rephrase_candidates(text)
    split_items = text.to_s.split(/\n?\s*\d+[.)]?\s*(?:\[[^\]]+\]\s*)?/)
    candidates = split_items.map { |item| item.to_s.strip }.compact_blank.map do |item|
      item.sub(/\A(?:短文|標準|フォーマル)\s*[:：]\s*/, "").strip
    end

    candidates = [text.to_s.strip] if candidates.blank?
    candidates.first(3)
  end

  # rubocop:disable Metrics/MethodLength
  def normalize_hit_type_value(raw_value)
    key = case raw_value
          when Symbol
            raw_value.to_s
          when String
            raw_value.strip
          when Integer
            SearchLog.hit_types.key(raw_value)
          else
            raw_value.to_s.strip
          end

    if SearchLog.hit_types.key?(key)
      key.to_sym
    else
      Rails.logger.warn("[rephrase#create] invalid hit_type detected: #{raw_value.inspect}. fallback to :none")
      :none
    end
  end
  # rubocop:enable Metrics/MethodLength

  def log_validation_failure(model_name:, errors:, attributes:)
    Rails.logger.error("[rephrase#create] #{model_name} 保存失敗")
    Rails.logger.error("[rephrase#create] #{model_name}.errors.full_messages: #{errors.join(', ')}")
    Rails.logger.error("[rephrase#create] #{model_name}.attributes: #{attributes.inspect}")
  end

  def log_search_log_category_association(search_log)
    category = Category.find_by(id: search_log.category_id)
    Rails.logger.error(
      "[rephrase#create] SearchLog.belongs_to(:category) check " \
      "category_id=#{search_log.category_id.inspect} category_exists=#{category.present?}"
    )
  rescue StandardError => e
    Rails.logger.error("[rephrase#create] category association check failed: #{e.class} - #{e.message}")
  end

  def extract_field_errors(error)
    return {} unless error.respond_to?(:record) && error.record.respond_to?(:errors)

    error.record.errors.each_with_object(Hash.new { |h, k| h[k] = [] }) do |err, result|
      result[err.attribute] << err.message
    end
  end

  def build_user_error_message(_error)
    return "保存に失敗しました。入力値を確認してください。" if @field_errors.blank?

    first_attr, messages = @field_errors.first
    if first_attr == :base
      messages.first.to_s
    else
      "#{human_field_label(first_attr)}: #{messages.first}"
    end
  end

  # rubocop:disable Metrics/MethodLength
  def human_field_label(attr)
    labels = {
      content: "入力文",
      scene: "シーン",
      target: "相手の関係性",
      context: "状況",
      category: "カテゴリ",
      category_id: "カテゴリ",
      query: "検索文",
      converted_text: "言い換え結果",
      hit_type: "判定種別",
      rephrase: "言い換え"
    }
    labels[attr.to_sym] || attr.to_s.humanize
  end
  # rubocop:enable Metrics/MethodLength
end
# rubocop:enable Metrics/ClassLength
