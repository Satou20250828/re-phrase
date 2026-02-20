# Handles search requests and persists conversion metadata.
class RephrasesController < ApplicationController
  def search
    return if params[:q].blank? || params[:category_id].blank?

    result = PhraseConverterService.new(query: params[:q], category_id: params[:category_id]).call
    assign_result_values(result)
    persist_search_log(result)
  rescue StandardError => e
    Rails.logger.error("SearchLog persistence failed: #{e.class} #{e.message}")
  end

  private

  def assign_result_values(result)
    @result_text = result[:result_text]
    @safety_mode_applied = result[:safety_mode_applied]
    @hit_type = result[:hit_type]
  end

  def persist_search_log(result)
    SearchLog.create!(
      query: params[:q],
      converted_text: @result_text,
      category_id: params[:category_id],
      **result.slice(:hit_type, :safety_mode_applied)
    )
  end
end
