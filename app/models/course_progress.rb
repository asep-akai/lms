class CourseProgress
  attr_reader :completed_modules, :total_modules

  def initialize(completed_modules:, total_modules:, completed_material_ids: [], completed_quiz_ids: [])
    @completed_modules = completed_modules
    @total_modules = total_modules
    @completed_material_ids = completed_material_ids
    @completed_quiz_ids = completed_quiz_ids
  end

  def completed?(course_content)
    if course_content.material?
      @completed_material_ids.include?(course_content.contentable_id)
    else
      @completed_quiz_ids.include?(course_content.contentable_id)
    end
  end

  def percentage
    return 0 if total_modules.zero?

    (completed_modules.fdiv(total_modules) * 100).round
  end

  def self.for(courses:, memberships:)
    courses = Array(courses)
    memberships = Array(memberships)
    course_ids = courses.map(&:id)
    membership_ids = memberships.map(&:id)
    totals = CourseContent.where(course_id: course_ids).group(:course_id).count
    completed_counts = Hash.new(0)
    completed_material_ids = Hash.new { |hash, key| hash[key] = [] }
    completed_quiz_ids = Hash.new { |hash, key| hash[key] = [] }

    MaterialCompletion.joins(material: :course)
      .where(membership_id: membership_ids, materials: { course_id: course_ids })
      .pluck("materials.course_id", :membership_id, :material_id)
      .each do |course_id, membership_id, material_id|
        key = [ course_id, membership_id ]
        completed_counts[key] += 1
        completed_material_ids[key] << material_id
      end

    QuizAttempt.joins(quiz: :course)
      .where(membership_id: membership_ids, quizzes: { course_id: course_ids })
      .where.not(submitted_at: nil)
      .pluck("quizzes.course_id", :membership_id, :quiz_id)
      .each do |course_id, membership_id, quiz_id|
        key = [ course_id, membership_id ]
        completed_counts[key] += 1
        completed_quiz_ids[key] << quiz_id
      end

    courses.each_with_object({}) do |course, progress_by_enrollment|
      memberships.each do |membership|
        key = [ course.id, membership.id ]
        progress_by_enrollment[key] = new(
          completed_modules: completed_counts[key],
          total_modules: totals.fetch(course.id, 0),
          completed_material_ids: completed_material_ids[key],
          completed_quiz_ids: completed_quiz_ids[key]
        )
      end
    end
  end
end
