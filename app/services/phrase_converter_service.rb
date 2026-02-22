# Converts an input query into a rephrased text for a given category.
# rubocop:disable Metrics/ClassLength
class PhraseConverterService
  TEMPERATURE_MIN = 0.7
  TEMPERATURE_MAX = 1.0

  # 既存の呼び出し口としてクラスメソッドを提供
  def self.call(query:, category_id:, scene: nil, target: nil, context: nil)
    new(query: query, category_id: category_id, scene: scene, target: target, context: context).call
  end

  def initialize(query:, category_id:, scene: nil, target: nil, context: nil)
    @query = query.to_s
    @category_id = category_id
    @scene = scene.to_s
    @target = target.to_s
    @context = context.to_s
  end

  def call
    ai_generated_result || local_generated_result
  end

  private

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def ai_generated_result
    return nil unless openai_available?

    temperature = random_temperature
    client = OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY"))
    response = client.chat(
      parameters: {
        model: ENV.fetch("OPENAI_MODEL", "gpt-4o-mini"),
        temperature: temperature,
        messages: ai_messages,
        max_tokens: 500
      }
    )

    content = response.dig("choices", 0, "message", "content").to_s
    variants = extract_variants(content)
    return nil if variants.empty?

    build_result(format_variants(variants), temperature: temperature, safety_mode_applied: false)
  rescue StandardError => e
    Rails.logger.warn("[phrase_converter] AI generation failed: #{e.class} - #{e.message}")
    nil
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def local_generated_result
    matched = matched_rephrase
    return fallback_result unless matched

    conversion_text = extract_conversion_text(matched.content)
    hit_type = matched.content.to_s.strip == @query ? :exact : :partial

    {
      result_text: conversion_text.presence || @query,
      safety_mode_applied: false,
      hit_type: hit_type,
      metadata: {
        category_id: @category_id,
        temperature: random_temperature
      }
    }
  end

  def build_result(text, temperature:, safety_mode_applied:)
    {
      result_text: text,
      safety_mode_applied: safety_mode_applied,
      hit_type: :none,
      metadata: {
        category_id: @category_id,
        temperature: temperature
      }
    }
  end

  def fallback_result
    build_result(@query, temperature: random_temperature, safety_mode_applied: true)
  end

  def openai_available?
    defined?(OpenAI::Client) && ENV["OPENAI_API_KEY"].present?
  end

  def random_temperature
    rand(TEMPERATURE_MIN..TEMPERATURE_MAX).round(2)
  end

  def ai_messages
    [
      {
        role: "system",
        content: "あなたは日本語の文章言い換えアシスタントです。丁寧で自然な表現を返してください。"
      },
      {
        role: "user",
        content: build_prompt
      }
    ]
  end

  def build_prompt
    <<~PROMPT
      次の文章を、用途に合わせて言い換えてください。
      入力された言葉をそのまま残すのではなく、文脈に合わせて語彙そのものを
      ビジネス・丁寧な日本語へ完全に置き換えてください。
      実行のたびに異なるニュアンス・語彙を使い、必ず3パターン提案してください。
      3パターンは似せず、以下のトーンで明確に差別化してください。
      1) 短文: 端的で読みやすい
      2) 標準: 丁寧で自然
      3) フォーマル: かしこまった敬語

      入力文: #{@query}
      シーン: #{@scene.presence || '未指定'}
      相手との関係: #{@target.presence || '未指定'}
      状況: #{@context.presence || '未指定'}

      置換例（Few-shot）:
      入力: こんにちわ
      1. お世話になっております。
      2. 平素より格別のご高配を賜り、厚く御礼申し上げます。
      3. 突然のご連絡失礼いたします。

      重要:
      - 入力文の語句（例: こんにちわ）をそのまま出力に含めないでください。
      - 同義・敬語表現へ語彙を置換してください。

      出力形式:
      1. [短文] ...
      2. [標準] ...
      3. [フォーマル] ...
    PROMPT
  end

  def extract_variants(content)
    content.to_s.lines.map(&:strip).filter_map do |line|
      normalized = line.sub(/\A[-*・]\s*/, "").sub(/\A\d+[.)]\s*/, "").strip
      normalized.presence
    end.first(3)
  end

  def format_variants(variants)
    variants.first(3).each_with_index.map { |v, i| "#{i + 1}. #{v}" }.join("\n")
  end

  def build_local_variants
    openers = %w[恐れ入りますが お手数ですが もしよろしければ 差し支えなければ]
    actions = %w[ご確認ください ご対応をお願いいたします ご共有いただけますか ご検討ください]
    closings = ["よろしくお願いいたします。", "助かります。", "ご確認のほどお願いいたします。"]

    variants = 3.times.map do
      "#{openers.sample}#{@query}について#{actions.sample} #{closings.sample}"
    end.uniq

    return variants if variants.size == 3

    variants.fill(variants.last.to_s, variants.size...3)
  end

  def matched_rephrase
    return nil if @category_id.blank?

    category_rephrases = Rephrase.where(category_id: @category_id)
    return nil if category_rephrases.empty?

    category_rephrases.find { |r| r.content.to_s.strip == @query } ||
      category_rephrases.find { |r| extract_source_text(r.content) == @query } ||
      category_rephrases.find { |r| partial_match?(r.content) }
  end

  def partial_match?(content)
    source = extract_source_text(content)
    return false if source.blank? || @query.blank?

    source.include?(@query) || @query.include?(source)
  end

  def extract_source_text(content)
    source, = split_mapping_content(content)
    normalize_phrase(source)
  end

  def extract_conversion_text(content)
    _, converted = split_mapping_content(content)
    normalize_phrase(converted).presence || content.to_s.strip
  end

  def split_mapping_content(content)
    text = content.to_s.strip
    return [text, nil] if text.blank?

    parts = text.split(/\s*(?:→|->|=>)\s*/, 2)
    return [text, nil] if parts.size < 2

    [parts[0], parts[1]]
  end

  def normalize_phrase(text)
    text.to_s.strip.gsub(/\A[「"']+|[」"']+\z/, "").strip
  end
end
# rubocop:enable Metrics/ClassLength
