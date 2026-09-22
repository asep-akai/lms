class ClassMeetingHistoryQuery
  def self.call(scope:, membership:, query:)
    new(scope: scope, membership: membership, query: query).call
  end

  def initialize(scope:, membership:, query:)
    @scope = scope
    @membership = membership
    @query = query.to_s.squish
  end

  def call
    meetings = @scope.past
    meetings = apply_search(meetings) if @query.present?
    meetings
      .includes(teacher_membership: :user, student_memberships: :user)
      .reverse_chronological
  end

  private
    def apply_search(meetings)
      escaped_query = ActiveRecord::Base.sanitize_sql_like(@query)
      pattern = "%#{escaped_query}%"
      matches = meetings.where(
        "class_meetings.subject ILIKE :query OR class_meetings.topic ILIKE :query",
        query: pattern
      )
      matches = matches.or(teacher_matches(meetings, pattern)) if @membership.student?
      matches = matches.or(student_matches(meetings, pattern)) if @membership.teacher?
      matches
    end

    def teacher_matches(meetings, pattern)
      teacher_ids = Membership
        .joins(:user)
        .where("users.name ILIKE :query", query: pattern)
        .select(:id)
      meetings.where(teacher_membership_id: teacher_ids)
    end

    def student_matches(meetings, pattern)
      class_meeting_ids = ClassMeetingStudent
        .joins(membership: :user)
        .where("users.name ILIKE :query", query: pattern)
        .select(:class_meeting_id)
      meetings.where(id: class_meeting_ids)
    end
end
