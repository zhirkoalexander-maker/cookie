class HeartbeatTrustScorer < ApplicationService
  CODE_EXTENSIONS = %w[
    .c .cc .cpp .cs .css .go .graphql .h .hpp .html .java .js .json .jsx .kt
    .lua .m .mdx .php .pl .py .rb .rs .scss .sh .sql .svelte .swift .toml .ts
    .tsx .vue .xml .yaml .yml
  ].freeze

  PASSIVE_EXTENSIONS = %w[
    .gif .jpeg .jpg .lock .log .md .pdf .png .svg .txt
  ].freeze

  VERIFIED_THRESHOLD = 0.7

  def initialize(heartbeat:)
    @heartbeat = heartbeat
  end

  def call
    reasons = []

    return verdict(0.0, [ "non_coding_category" ]) if non_coding_category?
    return verdict(0.0, [ "test_entry" ]) if test_entry?

    score = 0.0

    if typing_signal?
      score += 0.6
    else
      reasons << "no_typing_signal"
    end

    if code_context?
      score += 0.25
    else
      reasons << "not_code_like"
    end

    if heartbeat.project.present?
      score += 0.1
    else
      reasons << "missing_project"
    end

    if heartbeat.language.present?
      score += 0.1
    else
      reasons << "missing_language"
    end

    if passive_extension?
      score -= 0.2
      reasons << "passive_file_type"
    end

    if future_timestamp?
      score -= 0.4
      reasons << "future_timestamp"
    end

    score = score.clamp(0.0, 1.0).round(2)
    verdict(score, reasons)
  end

  private

  attr_reader :heartbeat

  def verdict(score, reasons)
    {
      trust_score: score,
      verified: score >= VERIFIED_THRESHOLD,
      trust_reasons: reasons.uniq.sort
    }
  end

  def typing_signal?
    heartbeat.is_write || heartbeat.line_additions.to_i.positive? || heartbeat.line_deletions.to_i.positive?
  end

  def code_context?
    heartbeat.language.present? || code_extension?
  end

  def code_extension?
    CODE_EXTENSIONS.include?(file_extension)
  end

  def passive_extension?
    PASSIVE_EXTENSIONS.include?(file_extension)
  end

  def file_extension
    File.extname(heartbeat.entity.to_s).downcase
  end

  def non_coding_category?
    heartbeat.category.to_s.present? && heartbeat.category.to_s.downcase != "coding"
  end

  def test_entry?
    heartbeat.source_type.to_s == "test_entry" || heartbeat.entity.to_s == "test.txt"
  end

  def future_timestamp?
    heartbeat.time.present? && heartbeat.time.to_f > 10.minutes.from_now.to_f
  end
end