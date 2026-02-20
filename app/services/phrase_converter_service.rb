# Converts an input query into a rephrased text for a given category.
class PhraseConverterService
  def initialize(query:, category_id:)
    @query = query.to_s
    @category_id = category_id
  end

  def call
    exact_match = scoped_rephrases.where(search_attribute.eq(@query)).first
    return build_hit_result(exact_match, :exact) if exact_match

    partial_match = find_partial_match
    return build_hit_result(partial_match, :partial) if partial_match

    fallback_result
  end

  private

  def scoped_rephrases
    Rephrase.where(category_id: @category_id)
  end

  def search_column
    Rephrase.column_names.include?("keyword") ? :keyword : :content
  end

  def find_partial_match
    scoped_rephrases.where(search_attribute.matches("%#{@query}%")).first
  end

  def search_attribute
    Rephrase.arel_table[search_column]
  end

  def build_hit_result(rephrase, hit_type)
    {
      result_text: extract_result_text(rephrase.content),
      safety_mode_applied: false,
      hit_type: hit_type
    }
  end

  def fallback_result
    {
      result_text: @query,
      safety_mode_applied: true,
      hit_type: :none
    }
  end

  def extract_result_text(content)
    value = content.to_s
    return value unless value.include?("→")

    value.split("→", 2).last.strip.delete_prefix("「").delete_suffix("」")
  end
end
