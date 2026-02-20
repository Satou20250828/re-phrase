# Handles search requests and persists conversion metadata.
class RephrasesController < ApplicationController
  def search
    return if params[:q].blank? || params[:category_id].blank?

    result = PhraseConverterService.new(query: params[:q], category_id: params[:category_id]).call
    @result_text = result[:result_text]

    persist_search_log(result)
  end

  private

  def persist_search_log(result)
    search_log = SearchLog.create(search_log_attributes(result))
    return if search_log.persisted?

    Rails.logger.warn("SearchLog validation failed: #{search_log.errors.full_messages.join(', ')}")
  rescue StandardError => e
    Rails.logger.error("SearchLog persistence failed: #{e.class} #{e.message}")
  end

  def search_log_attributes(result)
    result.slice(:hit_type, :safety_mode_applied).merge(
      query: params[:q],
      converted_text: result[:result_text],
      category_id: params[:category_id]
    )
  end
end
