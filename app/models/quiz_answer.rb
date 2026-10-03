class QuizAnswer < ApplicationRecord
  OPENAI_AUDIO_TYPES = %w[
    audio/wav
    audio/mp3
    audio/mpeg
    audio/m4a
    audio/webm
  ].freeze
  AUDIO_TYPE_ALIASES = {
    "audio/x-wav" => "audio/wav",
    "audio/x-m4a" => "audio/m4a",
    "audio/mp4" => "audio/m4a",
    "video/mp4" => "audio/m4a",
    "video/webm" => "audio/webm"
  }.freeze
  ALLOWED_AUDIO_TYPES = (OPENAI_AUDIO_TYPES + AUDIO_TYPE_ALIASES.keys).freeze
  MAX_AUDIO_SIZE = 25.megabytes

  belongs_to :quiz_attempt, inverse_of: :answers
  belongs_to :quiz_question
  belongs_to :quiz_answer_option, optional: true
  has_many :answer_selections, class_name: "QuizAnswerSelection", dependent: :destroy, inverse_of: :quiz_answer
  has_many :selected_options, through: :answer_selections, source: :quiz_answer_option
  has_many :cloze_responses, class_name: "QuizClozeResponse", dependent: :destroy, inverse_of: :quiz_answer
  has_one_attached :audio_response

  validate :answer_matches_question_type
  validate :audio_response_is_supported
  validates :short_answer_response, length: { maximum: 50_000 }, allow_nil: true

  def ai_audio_content_type
    AUDIO_TYPE_ALIASES.fetch(audio_response.blob.content_type, audio_response.blob.content_type) if audio_response.attached?
  end

  def submitted_selected_option_ids=(values)
    @submitted_selected_option_ids = Array(values).compact_blank.map(&:to_i).uniq
  end

  def submitted_cloze_responses=(values)
    @submitted_cloze_responses = values.to_h.each_with_object({}) do |(position, response), normalized|
      normalized[position.to_i] = response.to_s
    end
  end

  def save_submission
    transaction do
      save!
      sync_selected_options! if quiz_question.multiple_choice_set?
      sync_cloze_responses! if quiz_question.cloze?
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def response_present?
    if quiz_question.multiple_choice?
      quiz_answer_option_id.present?
    elsif quiz_question.multiple_choice_set?
      effective_selected_option_ids.any?
    elsif quiz_question.cloze?
      effective_cloze_responses.values.any?(&:present?)
    elsif quiz_question.audio?
      audio_response.attached?
    else
      short_answer_response.present?
    end
  end

  def complete?
    return false unless response_present?
    return effective_cloze_responses.values_at(*(1..quiz_question.cloze_answers.size)).all?(&:present?) if quiz_question.cloze?

    true
  end

  def cloze_response_at(position)
    effective_cloze_responses[position.to_i].to_s
  end

  def selected_option_ids_for_form
    effective_selected_option_ids
  end

  private
    def answer_matches_question_type
      return unless quiz_question

      if quiz_question.multiple_choice?
        errors.add(:quiz_answer_option, "must be a choice for this question") unless quiz_question.answer_options.exists?(id: quiz_answer_option_id)
      elsif quiz_question.multiple_choice_set?
        validate_multiple_choice_set
      elsif quiz_question.cloze?
        validate_cloze_responses
      elsif quiz_question.audio?
        errors.add(:audio_response, "must include a recording or uploaded audio file") unless audio_response.attached?
      elsif short_answer_response.blank?
        errors.add(:short_answer_response, "cannot be blank")
      end
    end

    def validate_multiple_choice_set
      option_ids = effective_selected_option_ids
      errors.add(:selected_options, "must include at least one choice") if option_ids.empty?
      valid_count = quiz_question.answer_options.where(id: option_ids).count
      errors.add(:selected_options, "must belong to this question") unless valid_count == option_ids.size
    end

    def validate_cloze_responses
      responses = effective_cloze_responses
      errors.add(:cloze_responses, "must include at least one answer") unless responses.values.any?(&:present?)
      valid_positions = 1..quiz_question.cloze_answers.size
      errors.add(:cloze_responses, "must match the blanks in this question") unless responses.keys.all? { |position| valid_positions.cover?(position) }
      errors.add(:cloze_responses, "must be 1,000 characters or fewer") if responses.values.any? { |response| response.length > 1_000 }
    end

    def effective_selected_option_ids
      return @submitted_selected_option_ids if defined?(@submitted_selected_option_ids)

      answer_selections.map(&:quiz_answer_option_id)
    end

    def effective_cloze_responses
      return @submitted_cloze_responses if defined?(@submitted_cloze_responses)

      cloze_responses.index_by(&:position).transform_values(&:response_text)
    end

    def sync_selected_options!
      answer_selections.delete_all
      @submitted_selected_option_ids.each do |option_id|
        answer_selections.create!(quiz_answer_option_id: option_id)
      end
      answer_selections.reset
      selected_options.reset
    end

    def sync_cloze_responses!
      cloze_responses.delete_all
      @submitted_cloze_responses.each do |position, response|
        cloze_responses.create!(position: position, response_text: response) if response.present?
      end
      cloze_responses.reset
    end

    def audio_response_is_supported
      return unless audio_response.attached?

      errors.add(:audio_response, "must use an AI-compatible audio format") unless audio_response.blob.content_type.in?(ALLOWED_AUDIO_TYPES)
      errors.add(:audio_response, "must be 25 MB or smaller") if audio_response.blob.byte_size > MAX_AUDIO_SIZE
    end
end
