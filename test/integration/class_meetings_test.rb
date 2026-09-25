require "test_helper"

class ClassMeetingsTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @teacher = create_member("teacher", "teacher@example.com", "Teacher One")
    @student = create_member("student", "student-one@example.com", "Student One")
    @other_student = create_member("student", "student-two@example.com", "Student Two")
  end

  test "administrator schedules a class and queues email for the teacher and students" do
    sign_in users(:one)

    assert_enqueued_emails 2 do
      post organization_class_meetings_path(organizations(:one)), params: {
        class_meeting: {
          teacher_membership_id: @teacher.id,
          student_membership_ids: [ @student.id ],
          subject: "Mathematics",
          topic: "Introduction to algebra",
          starts_at: "2026-10-10T08:30",
          delivery_mode: "online",
          meeting_url: "https://meet.example.com/algebra"
        }
      }
    end

    meeting = ClassMeeting.order(:id).last
    assert_redirected_to organization_class_meeting_path(organizations(:one), meeting)
    assert_equal 1, meeting.meeting_number
    assert_equal Time.zone.local(2026, 10, 10, 8, 30), meeting.starts_at
    assert_equal [ @student.id ], meeting.student_membership_ids
    assert_equal "https://meet.example.com/algebra", meeting.meeting_url
    assert AuditEvent.exists?(action: "class_meeting.created", auditable: meeting)

    get organization_class_meeting_path(organizations(:one), meeting)
    assert_response :success
    assert_select "h1", "Introduction to algebra"
    assert_select "dd", "Teacher One"
    assert_select "strong", "Student One"
    assert_select "a[href='https://meet.example.com/algebra']", text: "Join online class"
  end

  test "assigned teachers and students see the meeting while other students do not" do
    meeting = create_meeting

    sign_in @teacher.user
    get organization_class_meetings_path(organizations(:one))
    assert_response :success
    assert_select "h2", "Introduction to algebra"
    assert_select "a", text: "Edit class", count: 0

    sign_in @student.user
    get organization_class_meeting_path(organizations(:one), meeting)
    assert_response :success

    sign_in @other_student.user
    get organization_class_meeting_path(organizations(:one), meeting)
    assert_redirected_to root_path
    get organization_class_meetings_path(organizations(:one))
    assert_response :success
    assert_select "h2", { text: "Introduction to algebra", count: 0 }
  end

  test "student calendar shows assigned classes and opens a scoped day modal" do
    meeting = create_meeting
    sign_in @student.user

    get organization_class_meetings_path(organizations(:one), month: "2026-10")

    assert_response :success
    assert_select "turbo-frame#class-meeting-calendar"
    assert_select "h2", "October 2026"
    assert_select "a[aria-label='View classes on 10 October 2026']", text: /15:30 WIB.*Mathematics/m
    assert_select "a", text: "Today"

    get calendar_day_organization_class_meetings_path(organizations(:one), date: "2026-10-10", modal: 1),
      headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal"
    assert_select "h2", "Saturday, 10 October 2026"
    assert_select "h3", "Mathematics · Meeting 1"
    expected_detail_path = organization_class_meeting_path(organizations(:one), meeting, month: "2026-10")
    assert_select "a", text: "View class" do |links|
      assert_includes links.map { |link| link["href"] }, expected_detail_path
    end
  end

  test "student dashboard includes the assigned-class calendar" do
    create_meeting
    sign_in @student.user

    get organization_path(organizations(:one), month: "2026-10")

    assert_response :success
    assert_select "turbo-frame#class-meeting-calendar"
    assert_select "h2", "October 2026"
    assert_select "a[aria-label='View classes on 10 October 2026']", text: /Mathematics/
  end

  test "unassigned students cannot see classes in a calendar day" do
    create_meeting
    sign_in @other_student.user

    get calendar_day_organization_class_meetings_path(organizations(:one), date: "2026-10-10", modal: 1),
      headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "h2", "Saturday, 10 October 2026"
    assert_select "h3", count: 0
    assert_select "p", "No classes are scheduled for this day."
  end

  test "student class history contains past assigned classes in reverse chronological order" do
    older = create_meeting(subject: "History", topic: "Ancient civilizations", starts_at: 10.days.ago)
    recent = create_meeting(subject: "Science", topic: "Recent experiment", starts_at: 2.days.ago)
    future = create_meeting(subject: "Mathematics", topic: "Future lesson", starts_at: 2.days.from_now)
    sign_in @student.user

    get history_organization_class_meetings_path(organizations(:one))

    assert_response :success
    assert_select "a[aria-current='page']", "Class history"
    history_ids = css_select("article[data-class-meeting-id]").map { |article| article["data-class-meeting-id"].to_i }
    assert_equal [ recent.id, older.id ], history_ids
    assert_select "article[data-class-meeting-id='#{future.id}']", count: 0
    assert_select "dt", "Teacher"
    assert_select "dd", "Teacher One"
  end

  test "student searches class history by subject topic and teacher name" do
    second_teacher = create_member("teacher", "specialist@example.com", "Science Specialist")
    biology = create_meeting(subject: "Biology", topic: "Cell division", starts_at: 3.days.ago, teacher: second_teacher)
    create_meeting(subject: "Mathematics", topic: "Linear equations", starts_at: 4.days.ago)
    sign_in @student.user

    get history_organization_class_meetings_path(organizations(:one)), params: { query: "specialist" }
    assert_response :success
    assert_select "article[data-class-meeting-id='#{biology.id}']"
    assert_select "article[data-class-meeting-id]", count: 1

    get history_organization_class_meetings_path(organizations(:one)), params: { query: "cell division" }
    assert_select "article[data-class-meeting-id='#{biology.id}']"
  end

  test "teacher searches class history by student name" do
    other_student_meeting = create_meeting(
      subject: "Physics",
      topic: "Forces",
      starts_at: 3.days.ago,
      students: [ @other_student ]
    )
    create_meeting(subject: "Mathematics", topic: "Functions", starts_at: 4.days.ago)
    sign_in @teacher.user

    get history_organization_class_meetings_path(organizations(:one)), params: { query: "Student Two" }

    assert_response :success
    assert_select "article[data-class-meeting-id='#{other_student_meeting.id}']"
    assert_select "article[data-class-meeting-id]", count: 1
    assert_select "dt", "Students"
    assert_select "dd", "Student Two"
  end

  test "teacher history remains limited to assigned classes with broader viewing permission" do
    assigned = create_meeting(subject: "Assigned", starts_at: 2.days.ago)
    second_teacher = create_member("teacher", "other-teacher@example.com", "Other Teacher")
    unassigned = create_meeting(subject: "Unassigned", starts_at: 3.days.ago, teacher: second_teacher)
    viewer_role = organizations(:one).roles.create!(name: "Class viewer", key: "class_viewer")
    viewer_role.permissions = [ Permission.find_by!(key: "class_meetings.index") ]
    @teacher.role_ids = [ organizations(:one).roles.find_by!(key: "teacher").id, viewer_role.id ]
    sign_in @teacher.user

    get history_organization_class_meetings_path(organizations(:one))

    assert_response :success
    assert_select "article[data-class-meeting-id='#{assigned.id}']"
    assert_select "article[data-class-meeting-id='#{unassigned.id}']", count: 0
  end

  test "students submit private feedback that only their teacher can read" do
    meeting = create_meeting(starts_at: 2.hours.ago, students: [ @student, @other_student ])
    sign_in @student.user

    get history_organization_class_meetings_path(organizations(:one))
    assert_response :success
    assert_select "article[data-class-meeting-id='#{meeting.id}']" do
      assert_select "a", text: "Give feedback"
    end

    assert_difference "ClassMeetingFeedback.count", 1 do
      post organization_class_meeting_feedbacks_path(organizations(:one), meeting), params: {
        class_meeting_feedback: { rating: 5, comment: "The explanation was clear." }
      }
    end

    feedback = meeting.feedbacks.find_by!(author_membership: @student)
    assert_equal "student", feedback.author_role
    assert_redirected_to history_organization_class_meetings_path(organizations(:one))

    get history_organization_class_meetings_path(organizations(:one))
    assert_select "a", text: "View your feedback"

    sign_in @other_student.user
    get organization_class_meeting_feedback_path(organizations(:one), meeting, feedback)
    assert_response :not_found
    get organization_class_meeting_feedbacks_path(organizations(:one), meeting)
    assert_response :success
    assert_select "h2", text: @student.user.name, count: 0

    sign_in @teacher.user
    get organization_class_meeting_feedbacks_path(organizations(:one), meeting)
    assert_response :success
    assert_select "h2", @student.user.name
    assert_select "span", "5/5"
    assert_select "p", "The explanation was clear."
  end

  test "teacher feedback is shared with every assigned student while its internal note stays private" do
    meeting = create_meeting(starts_at: 2.hours.ago, students: [ @student, @other_student ])
    sign_in @teacher.user

    assert_difference "ClassMeetingFeedback.count", 1 do
      post organization_class_meeting_feedbacks_path(organizations(:one), meeting), params: {
        class_meeting_feedback: {
          rating: 4,
          internal_feedback: "The group needs more confidence with denominators.",
          feedback_to_student: "Good collaboration during the exercises.",
          topics_discussed: "Equivalent fractions",
          next_topics: "Adding fractions"
        }
      }
    end

    feedback = meeting.feedbacks.find_by!(author_membership: @teacher)
    assert_equal "teacher", feedback.author_role

    [ @student, @other_student ].each do |student|
      sign_in student.user
      get organization_class_meeting_feedback_path(organizations(:one), meeting, feedback)
      assert_response :success
      assert_select "dd", "4/5"
      assert_select "p", "Good collaboration during the exercises."
      assert_select "p", "Equivalent fractions"
      assert_select "p", "Adding fractions"
      assert_select "p", text: "The group needs more confidence with denominators.", count: 0
    end

    sign_in @teacher.user
    get organization_class_meeting_feedback_path(organizations(:one), meeting, feedback)
    assert_response :success
    assert_select "h2", "Internal feedback"
    assert_select "p", "The group needs more confidence with denominators."
  end

  test "administrator reviews and filters teacher and student feedback" do
    meeting = create_meeting(
      subject: "Mathematics",
      topic: "Equivalent fractions",
      starts_at: 2.hours.ago,
      students: [ @student, @other_student ]
    )
    teacher_feedback = meeting.feedbacks.create!(
      author_membership: @teacher,
      author_role: "teacher",
      rating: 4,
      internal_feedback: "Revisit denominators before the next lesson.",
      feedback_to_student: "The group worked well together.",
      topics_discussed: "Equivalent fractions",
      next_topics: "Adding fractions"
    )
    student_feedback = meeting.feedbacks.create!(
      author_membership: @student,
      author_role: "student",
      rating: 5,
      comment: "The examples were clear."
    )
    second_teacher = create_member("teacher", "second-teacher@example.com", "Second Teacher")
    other_meeting = create_meeting(
      subject: "Science",
      topic: "Forces",
      starts_at: 3.hours.ago,
      teacher: second_teacher,
      students: [ @other_student ]
    )
    other_feedback = other_meeting.feedbacks.create!(
      author_membership: @other_student,
      author_role: "student",
      rating: 2,
      comment: "I needed more examples."
    )
    sign_in users(:one)

    get organization_class_feedback_path(organizations(:one))

    assert_response :success
    assert_select "a[aria-current='page']", "Feedback"
    assert_select "tr[data-feedback-id]", count: 3
    assert_select "tr[data-feedback-id='#{teacher_feedback.id}']", text: /Teacher One/
    assert_select "tr[data-feedback-id='#{student_feedback.id}']", text: /Student One/

    get organization_class_feedback_path(organizations(:one)), params: { author_role: "teacher" }
    assert_select "tr[data-feedback-id='#{teacher_feedback.id}']"
    assert_select "tr[data-feedback-id='#{student_feedback.id}']", count: 0
    assert_select "tr[data-feedback-id='#{other_feedback.id}']", count: 0

    get organization_class_feedback_path(organizations(:one)), params: { rating: 5 }
    assert_select "tr[data-feedback-id='#{student_feedback.id}']"
    assert_select "tr[data-feedback-id]", count: 1

    get organization_class_feedback_path(organizations(:one)), params: { teacher_id: @teacher.id }
    assert_select "tr[data-feedback-id='#{teacher_feedback.id}']"
    assert_select "tr[data-feedback-id='#{student_feedback.id}']"
    assert_select "tr[data-feedback-id='#{other_feedback.id}']", count: 0

    get organization_class_feedback_path(organizations(:one)), params: { student_id: @student.id }
    assert_select "tr[data-feedback-id='#{teacher_feedback.id}']"
    assert_select "tr[data-feedback-id='#{student_feedback.id}']"
    assert_select "tr[data-feedback-id='#{other_feedback.id}']", count: 0

    get organization_class_feedback_path(organizations(:one)), params: { query: "Student Two" }
    assert_select "tr[data-feedback-id='#{other_feedback.id}']"
    assert_select "tr[data-feedback-id]", count: 1

    detail_path = organization_class_meeting_feedback_path(
      organizations(:one),
      meeting,
      teacher_feedback,
      from: "feedback",
      author_role: "teacher"
    )
    get detail_path

    assert_response :success
    assert_select "h2", "Internal feedback"
    assert_select "p", "Revisit denominators before the next lesson."
    assert_select "a", text: "Back to feedback" do |links|
      expected_path = organization_class_feedback_path(organizations(:one), author_role: "teacher")
      assert_includes links.map { |link| link["href"] }, expected_path
    end
  end

  test "teachers cannot open the administrator feedback view" do
    sign_in @teacher.user

    get organization_class_feedback_path(organizations(:one))

    assert_redirected_to root_path
    get history_organization_class_meetings_path(organizations(:one))
    assert_select "a", text: "Feedback", count: 0
  end

  test "feedback cannot be submitted before class starts or submitted twice" do
    future_meeting = create_meeting(starts_at: 2.hours.from_now)
    sign_in @student.user

    assert_no_difference "ClassMeetingFeedback.count" do
      post organization_class_meeting_feedbacks_path(organizations(:one), future_meeting), params: {
        class_meeting_feedback: { rating: 5, comment: "Too early." }
      }
    end
    assert_redirected_to root_path

    past_meeting = create_meeting(subject: "Science", starts_at: 2.hours.ago)
    past_meeting.feedbacks.create!(
      author_membership: @student,
      author_role: "student",
      rating: 4
    )

    assert_no_difference "ClassMeetingFeedback.count" do
      post organization_class_meeting_feedbacks_path(organizations(:one), past_meeting), params: {
        class_meeting_feedback: { rating: 5, comment: "Second response." }
      }
    end
    assert_redirected_to root_path

    sign_in users(:one)
    assert_no_difference "ClassMeetingFeedback.count" do
      post organization_class_meeting_feedbacks_path(organizations(:one), past_meeting), params: {
        class_meeting_feedback: { rating: 5, comment: "Administrator response." }
      }
    end
    assert_redirected_to root_path
  end

  test "schedule list excludes previous classes" do
    past = create_meeting(topic: "Previous lesson", starts_at: 2.days.ago)
    future = create_meeting(topic: "Upcoming lesson", starts_at: 2.days.from_now)
    sign_in @student.user

    get organization_class_meetings_path(organizations(:one))

    assert_response :success
    assert_select "article", text: /Previous lesson/, count: 0
    assert_select "article", text: /Upcoming lesson/
    assert_select "a[href='#{history_organization_class_meetings_path(organizations(:one))}']", "Class history"
    assert ClassMeeting.exists?(past.id)
    assert ClassMeeting.exists?(future.id)
  end

  test "class details and editing preserve the history destination and search" do
    meeting = create_meeting(topic: "Navigation lesson", starts_at: 2.days.ago)
    history_path = history_organization_class_meetings_path(organizations(:one), query: "Navigation")
    detail_path = organization_class_meeting_path(
      organizations(:one),
      meeting,
      from: "history",
      history_query: "Navigation"
    )
    sign_in users(:one)

    get detail_path

    assert_response :success
    assert_select "a", text: "Back to class history" do |links|
      assert_includes links.map { |link| link["href"] }, history_path
    end
    edit_path = edit_organization_class_meeting_path(
      organizations(:one),
      meeting,
      from: "history",
      history_query: "Navigation"
    )
    assert_select "a", text: "Edit class" do |links|
      assert_includes links.map { |link| link["href"] }, edit_path
    end

    get edit_path

    assert_response :success
    assert_select "a", text: "Back to class" do |links|
      assert_includes links.map { |link| link["href"] }, detail_path
    end
    assert_select "input[name='from'][value='history']"
    assert_select "input[name='history_query'][value='Navigation']"
    assert_select "a", text: "Cancel" do |links|
      assert_includes links.map { |link| link["href"] }, detail_path
    end

    patch organization_class_meeting_path(organizations(:one), meeting), params: {
      from: "history",
      history_query: "Navigation",
      class_meeting: {
        teacher_membership_id: @teacher.id,
        student_membership_ids: [ @student.id ],
        subject: meeting.subject,
        topic: "Updated navigation lesson",
        starts_at: meeting.starts_at.in_time_zone(Organization::TIME_ZONE).strftime("%Y-%m-%dT%H:%M"),
        delivery_mode: meeting.delivery_mode,
        meeting_url: meeting.meeting_url
      }
    }

    assert_redirected_to detail_path
  end

  test "class details preserve the selected calendar month" do
    meeting = create_meeting
    sign_in @student.user

    get organization_class_meeting_path(organizations(:one), meeting, month: "2026-10")

    assert_response :success
    expected_path = organization_class_meetings_path(organizations(:one), month: "2026-10")
    assert_select "a", text: "Back to classes" do |links|
      assert_includes links.map { |link| link["href"] }, expected_path
    end
  end

  test "meeting number increments for the same subject" do
    first = create_meeting(subject: "Mathematics")
    second = create_meeting(subject: " mathematics ")

    assert_equal 1, first.meeting_number
    assert_equal 2, second.meeting_number
  end

  test "invalid updates do not partially replace student assignments" do
    meeting = create_meeting
    sign_in users(:one)

    patch organization_class_meeting_path(organizations(:one), meeting), params: {
      class_meeting: {
        teacher_membership_id: @teacher.id,
        student_membership_ids: [],
        subject: "Mathematics",
        topic: "Updated topic",
        starts_at: "2026-10-10T08:30",
        delivery_mode: "online",
        meeting_url: "https://meet.example.com/algebra"
      }
    }

    assert_response :unprocessable_entity
    assert_equal [ @student.id ], meeting.reload.student_membership_ids
    assert_equal "Introduction to algebra", meeting.topic
  end

  private
    def create_meeting(subject: "Mathematics", topic: "Introduction to algebra", starts_at: Time.utc(2026, 10, 10, 8, 30), teacher: @teacher, students: [ @student ])
      meeting = organizations(:one).class_meetings.new(
        teacher_membership: teacher,
        subject: subject,
        topic: topic,
        starts_at: starts_at,
        delivery_mode: "online",
        meeting_url: "https://meet.example.com/algebra"
      )
      meeting.student_memberships = students
      meeting.save!
      meeting
    end

    def create_member(role_key, email, name)
      user = User.create!(name: name, email: email, password: "password", status: "active")
      membership = organizations(:one).memberships.create!(user: user, status: "active")
      membership.role_ids = [ organizations(:one).roles.find_by!(key: role_key).id ]
      membership
    end
end
