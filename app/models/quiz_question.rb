class QuizQuestion < ApplicationRecord
  QUESTION_TYPES = {
    "Multiple choice" => "multiple_choice",
    "Multiple choice set" => "multiple_choice_set",
    "Short answer" => "short_answer",
    "Multiple answers (cloze)" => "cloze",
    "Essay" => "essay",
    "Audio" => "audio"
  }.freeze

  ALLOWED_HTML_TAGS = %w[p br strong b em i u ul ol li].freeze
  CLOZE_PATTERN = /\[\[([^\[\]\r\n]+)\]\]/
  SCORING_MODES = %w[scored feedback_only].freeze

  belongs_to :quiz, inverse_of: :questions
  belongs_to :quiz_page, inverse_of: :questions
  has_many :answer_options, class_name: "QuizAnswerOption", dependent: :destroy, inverse_of: :quiz_question
  has_many :answers, class_name: "QuizAnswer", dependent: :destroy
  has_many :answer_overrides, class_name: "QuizAnswerOverride", dependent: :destroy
  has_many :answer_ai_grades, class_name: "QuizAnswerAiGrade", dependent: :destroy
  has_many :answer_ai_transcriptions, class_name: "QuizAnswerAiTranscription", dependent: :destroy
  has_many :answer_feedbacks, class_name: "QuizAnswerFeedback", dependent: :destroy

  accepts_nested_attributes_for :answer_options, allow_destroy: true, reject_if: :blank_answer_option?

  enum :question_type, {
    multiple_choice: "multiple_choice",
    multiple_choice_set: "multiple_choice_set",
    short_answer: "short_answer",
    cloze: "cloze",
    essay: "essay",
    audio: "audio"
  }, validate: true

  validates :content_html, length: { maximum: 20_000 }
  validates :short_answer, presence: true, length: { maximum: 1_000 }, if: :short_answer?
  validates :cloze_template, length: { maximum: 20_000 }, if: :cloze?
  validates :scoring_mode, inclusion: { in: SCORING_MODES }, allow_nil: true
  validate :multiple_choice_has_valid_options
  validate :cloze_has_multiple_blanks
  validate :page_belongs_to_quiz

  before_validation :assign_default_page, on: :create
  before_validation :normalize_content_html

  def content_text?
    ActionView::Base.full_sanitizer.sanitize(content_html.to_s).squish.present?
  end

  def manual_grading? = essay? || audio?
  def included_in_score? = !manual_grading? || scoring_mode == "scored"
  def feedback_only? = manual_grading? && !included_in_score?

  def cloze_answers
    cloze_answer_sets.map(&:first)
  end

  def cloze_answer_sets
    cloze_template.to_s.scan(CLOZE_PATTERN).flatten.map do |answer_group|
      answer_group.split("|").map(&:strip)
    end
  end

  def cloze_segments
    template = cloze_template.to_s
    segments = []
    cursor = 0
    template.to_enum(:scan, CLOZE_PATTERN).each_with_index do |_match, index|
      match = Regexp.last_match
      segments << { text: template[cursor...match.begin(0)] } if match.begin(0) > cursor
      segments << { blank_position: index + 1 }
      cursor = match.end(0)
    end
    segments << { text: template[cursor..] } if cursor < template.length
    segments
  end

  private
    def normalize_content_html
      self.content_html ||= ""
    end

    def blank_answer_option?(attributes)
      attributes["content"].blank?
    end

    def multiple_choice_has_valid_options
      return unless multiple_choice? || multiple_choice_set?

      options = answer_options.reject(&:marked_for_destruction?)
      errors.add(:answer_options, "must include at least two choices") if options.size < 2
      if multiple_choice?
        errors.add(:answer_options, "must have exactly one correct choice") unless options.count(&:correct?) == 1
      else
        errors.add(:answer_options, "must have at least one correct choice") if options.none?(&:correct?)
        errors.add(:answer_options, "must include at least one incorrect choice") if options.all?(&:correct?)
      end
    end

    def cloze_has_multiple_blanks
      return unless cloze?

      errors.add(:cloze_template, "must include at least two answers in [[double brackets]]") if cloze_answers.size < 2
      errors.add(:cloze_template, "contains an empty answer or alternative") if cloze_answer_sets.flatten.any?(&:blank?)
    end

    def assign_default_page
      self.quiz_page ||= quiz&.default_page
    end

    def page_belongs_to_quiz
      return unless quiz && quiz_page
      return if quiz_page.quiz_id == quiz_id

      errors.add(:quiz_page, "must belong to this quiz")
    end
end
