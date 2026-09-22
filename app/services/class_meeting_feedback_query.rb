class ClassMeetingFeedbackQuery
  AUTHOR_ROLES = ClassMeetingFeedback::AUTHOR_ROLES.freeze
  RATINGS = (1..5).freeze

  def self.call(scope:, query: nil, author_role: nil, rating: nil, teacher_membership_id: nil, student_membership_id: nil)
    new(
      scope: scope,
      query: query,
      author_role: author_role,
      rating: rating,
      teacher_membership_id: teacher_membership_id,
      student_membership_id: student_membership_id
    ).call
  end

  def initialize(scope:, query:, author_role:, rating:, teacher_membership_id:, student_membership_id:)
    @scope = scope
    @query = query.to_s.squish.first(200)
    @author_role = author_role.to_s
    @rating = rating.to_i
    @teacher_membership_id = teacher_membership_id
    @student_membership_id = student_membership_id
  end

  def call
    feedbacks = @scope
    feedbacks = apply_search(feedbacks) if @query.present?
    feedbacks = feedbacks.where(author_role: @author_role) if @author_role.in?(AUTHOR_ROLES)
    feedbacks = feedbacks.where(rating: @rating) if @rating.in?(RATINGS)
    feedbacks = feedbacks.joins(:class_meeting).where(class_meetings: { teacher_membership_id: @teacher_membership_id }) if @teacher_membership_id
    feedbacks = feedbacks.where(class_meeting_id: student_meeting_ids) if @student_membership_id

    feedbacks
      .includes(author_membership: :user, class_meeting: [ { teacher_membership: :user }, { student_memberships: :user } ])
      .joins(:class_meeting)
      .order("class_meetings.starts_at DESC", created_at: :desc)
  end

  private
    def apply_search(feedbacks)
      escaped_query = ActiveRecord::Base.sanitize_sql_like(@query)
      pattern = "%#{escaped_query}%"
      matching_meetings = ClassMeeting
        .where(organization: Current.organization)
        .where("class_meetings.subject ILIKE :query OR class_meetings.topic ILIKE :query", query: pattern)
        .select(:id)
      matching_authors = Membership
        .where(organization: Current.organization)
        .joins(:user)
        .where("users.name ILIKE :query OR users.email ILIKE :query", query: pattern)
        .select(:id)

      feedbacks.where(class_meeting_id: matching_meetings)
        .or(feedbacks.where(author_membership_id: matching_authors))
    end

    def student_meeting_ids
      ClassMeetingStudent.where(membership_id: @student_membership_id).select(:class_meeting_id)
    end
end
