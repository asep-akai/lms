require "test_helper"

class TeacherStudentsTest < ActionDispatch::IntegrationTest
  setup do
    @teacher = create_member("teacher", "teacher-directory@example.com", "Directory Teacher")
    @student = create_member("student", "taught-student@example.com", "Taught Student")
    @other_student = create_member("student", "untaught-student@example.com", "Untaught Student")
    create_class_meeting
    @attempt = create_reviewed_attempt
    @certificate = Certificates::Generate.call(
      source: @attempt,
      issued_by: organizations(:one).memberships.find_by!(user: users(:one))
    )
  end

  test "teacher sees only taught students and their learning records" do
    sign_in @teacher.user

    get organization_students_path(organizations(:one))

    assert_response :success
    assert_select "a[href='#{organization_students_path(organizations(:one))}']", text: "Students"
    assert_select "a[href='#{organization_certificates_path(organizations(:one))}']", count: 0
    assert_select "tr", text: /Taught Student/
    assert_select "tr", { text: /Untaught Student/, count: 0 }
    assert_select "a[href='#{organization_student_path(organizations(:one), @student)}']", text: "View student"
    assert_select "a", text: "Enroll in course", count: 0

    get organization_student_path(organizations(:one), @student)

    assert_response :success
    assert_select "#course-progress-heading", "Course progress"
    assert_select "section", text: /Biology.*1 of 1 module completed.*100%/m
    assert_select "#quiz-attempts-heading", "Quiz attempts"
    assert_select "tr[data-quiz-attempt-id='#{@attempt.id}']", text: /Cells assessment.*Reviewed.*1\/1.*100%/m
    assert_select "a[href='#{organization_evaluation_attempt_path(organizations(:one), @attempt, from: "student")}']", text: "View results"
    assert_select "#student-certificates-heading", "Certificates"
    assert_select "article[data-certificate-id='#{@certificate.id}']", text: /Cells assessment.*1\/1.*100%/m
    assert_select "a[href='#{organization_certificate_path(organizations(:one), @certificate, from: "student")}']", text: "View certificate"

    get organization_student_path(organizations(:one), @other_student)
    assert_response :not_found
  end

  test "teacher opens a taught student's reviewed attempt from the student profile" do
    sign_in @teacher.user

    get organization_evaluation_attempt_path(organizations(:one), @attempt, from: "student")

    assert_response :success
    assert_select "a", text: "Back to student" do |links|
      assert_includes links.map { |link| link["href"] }, organization_student_path(organizations(:one), @student)
    end
    assert_select "p", "Student answer"
    assert_select "p", text: /Mitochondrion/
  end

  test "teacher opens a taught student's certificate from the student profile" do
    sign_in @teacher.user

    get organization_certificate_path(organizations(:one), @certificate, from: "student")

    assert_response :success
    assert_select "a", text: "Back to student" do |links|
      assert_includes links.map { |link| link["href"] }, organization_student_path(organizations(:one), @student)
    end
  end

  test "teacher searches their student directory" do
    second_student = create_member("student", "second-directory-student@example.com", "Second Directory Student")
    create_class_meeting_for(second_student)
    sign_in @teacher.user

    get organization_students_path(organizations(:one), query: @student.user.email)

    assert_response :success
    assert_select "input[type='search'][name='query'][value='#{@student.user.email}']"
    assert_select "tr", text: /Taught Student/
    assert_select "tr", { text: /Second Directory Student/, count: 0 }
  end

  private
    def create_class_meeting
      meeting = organizations(:one).class_meetings.new(
        teacher_membership: @teacher,
        subject: "Biology",
        topic: "Cells",
        starts_at: 1.day.ago,
        delivery_mode: "onsite"
      )
      meeting.student_memberships = [ @student ]
      meeting.save!
    end

    def create_class_meeting_for(student)
      meeting = organizations(:one).class_meetings.new(
        teacher_membership: @teacher,
        subject: "Chemistry",
        topic: "Elements",
        starts_at: 2.days.ago,
        delivery_mode: "onsite"
      )
      meeting.student_memberships = [ student ]
      meeting.save!
    end

    def create_reviewed_attempt
      course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
      course.course_enrollments.create!(membership: @student)
      quiz = course.quizzes.create!(title: "Cells assessment")
      question = quiz.questions.create!(
        question_type: "short_answer",
        content_html: "<p>Name an organelle.</p>",
        short_answer: "Mitochondrion",
        position: 1
      )
      attempt = QuizAttempt.create!(
        quiz: quiz,
        membership: @student,
        started_at: 2.hours.ago,
        last_activity_at: 1.hour.ago,
        submitted_at: 1.hour.ago,
        reviewed_at: Time.current
      )
      attempt.answers.create!(quiz_question: question, short_answer_response: "Mitochondrion")
      attempt
    end

    def create_member(role_key, email, name)
      user = User.create!(name: name, email: email, password: "password", status: "active")
      membership = organizations(:one).memberships.create!(user: user, status: "active")
      membership.role_ids = [ organizations(:one).roles.find_by!(key: role_key).id ]
      membership
    end
end
