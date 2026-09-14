class QuizQuestion < ApplicationRecord
  QUESTION_TYPES = {
    "Multiple choice" => "multiple_choice",
    "Short answer" => "short_answer"
  }.freeze

  ALLOWED_HTML_TAGS = %w[p br strong b em i u ul ol li].freeze

  belongs_to :quiz, inverse_of: :questions
  has_many :answer_options, class_name: "QuizAnswerOption", dependent: :destroy, inverse_of: :quiz_question
  has_many :answers, class_name: "QuizAnswer", dependent: :destroy
  has_many :answer_overrides, class_name: "QuizAnswerOverride", dependent: :destroy

  accepts_nested_attributes_for :answer_options, allow_destroy: true, reject_if: :blank_answer_option?

  enum :question_type, { multiple_choice: "multiple_choice", short_answer: "short_answer" }, validate: true

  validates :content_html, presence: true, length: { maximum: 20_000 }
  validates :short_answer, presence: true, length: { maximum: 1_000 }, if: :short_answer?
  validate :content_has_text
  validate :multiple_choice_has_valid_options

  private
    def blank_answer_option?(attributes)
      attributes["content"].blank?
    end

    def content_has_text
      return if ActionView::Base.full_sanitizer.sanitize(content_html).squish.present?

      errors.add(:content_html, "must include question text")
    end

    def multiple_choice_has_valid_options
      return unless multiple_choice?

      options = answer_options.reject(&:marked_for_destruction?)
      errors.add(:answer_options, "must include at least two choices") if options.size < 2
      errors.add(:answer_options, "must have exactly one correct choice") unless options.count(&:correct?) == 1
    end
end
