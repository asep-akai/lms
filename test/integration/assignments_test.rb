require "test_helper"

class AssignmentsTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @teacher = create_member("teacher", "teacher-assignments@example.com", "Teacher Assignments")
    @student = create_member("student", "student-assignments@example.com", "Student Assignments")
    @other_student = create_member("student", "other-student-assignments@example.com", "Other Student")
    create_class_meeting
  end

  test "teacher creates an assignment only for a student they have taught" do
    sign_in @teacher.user

    get new_organization_assignment_path(organizations(:one), student_id: @student.id)
    assert_response :success
    assert_select "input[name='assignment[student_ids][]'][value='#{@student.id}'][checked]"
    assert_select "input[name='assignment[student_ids][]'][value='#{@other_student.id}']", count: 0

    assert_enqueued_emails 1 do
      post organization_assignments_path(organizations(:one)), params: {
        assignment: {
          title: "Field notes",
          description: "Write a short summary of today's class.",
          deadline: 2.days.from_now.strftime("%Y-%m-%dT%H:%M"),
          student_ids: [ @student.id, @other_student.id ],
          document: fixture_file_upload("assignment.txt", "text/plain")
        }
      }
    end

    assignment = Assignment.order(:id).last
    assert_redirected_to organization_assignment_path(organizations(:one), assignment)
    assert_equal [ @student.id ], assignment.student_membership_ids
    assert assignment.document.attached?
    assert AuditEvent.exists?(action: "assignment.created", auditable: assignment)
  end

  test "assignment deadlines are entered and displayed in WIB" do
    organizations(:one).update!(timezone: "Jakarta")
    sign_in @teacher.user

    get new_organization_assignment_path(organizations(:one))
    assert_response :success
    assert_select ".hint", "Shown in WIB."

    post organization_assignments_path(organizations(:one)), params: {
      assignment: {
        title: "WIB deadline",
        description: "Confirm the local deadline.",
        deadline: "2030-01-02T10:00",
        student_ids: [ @student.id ]
      }
    }

    assignment = Assignment.order(:id).last
    assert_equal Time.utc(2030, 1, 2, 3, 0), assignment.deadline
    follow_redirect!
    assert_select "p", text: /2 January 2030 at 10:00 WIB/
  end

  test "student saves a draft, submits it late, and cannot modify it afterward" do
    assignment = create_assignment
    recipient = assignment.recipients.find_by!(student_membership: @student)
    sign_in @student.user

    patch organization_assignment_submission_path(organizations(:one), assignment), params: {
      assignment_submission: {
        body: "My draft response",
        documents: [ fixture_file_upload("assignment.txt", "text/plain") ]
      }
    }

    submission = recipient.reload.submission
    assert_redirected_to organization_assignment_path(organizations(:one), assignment)
    assert_equal "My draft response", submission.body
    assert_not submission.submitted?
    assert_equal 1, submission.documents.count

    assignment.update_column(:deadline, 1.hour.ago)
    assert_enqueued_emails 1 do
      patch organization_assignment_submission_path(organizations(:one), assignment), params: {
        assignment_submission: { body: "My final response" },
        submit_assignment: "1"
      }
    end

    submission.reload
    assert submission.submitted?
    assert submission.late?
    assert_equal "My final response", submission.body
    assert AuditEvent.exists?(action: "assignment.submitted", auditable: assignment)

    patch organization_assignment_submission_path(organizations(:one), assignment), params: {
      assignment_submission: { body: "Changed after submission" }
    }

    assert_redirected_to root_path
    assert_equal "My final response", submission.reload.body
  end

  test "student can submit after the deadline and sees a late status" do
    assignment = create_assignment
    assignment.update_column(:deadline, 1.hour.ago)
    sign_in @student.user

    get organization_assignment_path(organizations(:one), assignment)
    assert_response :success
    assert_select "span", "Late"
    assert_select "button[type='submit']", "Submit assignment"

    patch organization_assignment_submission_path(organizations(:one), assignment), params: {
      assignment_submission: { body: "Late work" },
      submit_assignment: "1"
    }

    assert_redirected_to organization_assignment_path(organizations(:one), assignment)
    follow_redirect!
    assert_select "span", "Submitted late"
  end

  test "teacher reviews a submission and emails a comment to the student" do
    assignment = create_assignment
    recipient = assignment.recipients.find_by!(student_membership: @student)
    submission = recipient.create_submission!(body: "Completed work", submitted_at: Time.current)
    sign_in @teacher.user

    get organization_assignment_path(organizations(:one), assignment)
    assert_response :success
    assert_select "article[data-recipient-id='#{recipient.id}']", text: /Completed work/

    assert_enqueued_emails 1 do
      patch organization_assignment_recipient_comment_path(organizations(:one), assignment, recipient_id: recipient.id), params: {
        assignment_submission: { teacher_comment: "Please expand your second paragraph." }
      }
    end

    assert_redirected_to organization_assignment_path(organizations(:one), assignment)
    assert_equal "Please expand your second paragraph.", submission.reload.teacher_comment
    assert AuditEvent.exists?(action: "assignment.commented", auditable: assignment)
  end

  test "an unassigned student cannot open the assignment" do
    assignment = create_assignment
    sign_in @other_student.user

    get organization_assignment_path(organizations(:one), assignment)

    assert_response :not_found
  end

  test "student sees the deadline and downloads private assignment and submission documents" do
    assignment = create_assignment(document: true)
    recipient = assignment.recipients.find_by!(student_membership: @student)
    submission = recipient.create_submission!(body: "Work", submitted_at: Time.current)
    submission.documents.attach(io: file_fixture("assignment.txt").open, filename: "student-work.txt", content_type: "text/plain")
    sign_in @student.user

    get organization_assignment_path(organizations(:one), assignment)
    assert_response :success
    assert_select "p", text: /Deadline/
    assert_select "a", text: "assignment.txt"
    assert_select "a", text: "student-work.txt"

    get document_organization_assignment_path(organizations(:one), assignment)
    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_equal "Read the attached instructions and submit your response.\n", response.body

    attachment = submission.documents_attachments.first
    get organization_assignment_submission_document_path(
      organizations(:one),
      assignment,
      submission_id: submission.id,
      attachment_id: attachment.id
    )
    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  test "teacher updates their assignment and its student list" do
    second_student = create_member("student", "second-taught-student@example.com", "Second Taught Student")
    create_class_meeting(students: [ second_student ], subject: "Editing")
    assignment = create_assignment(document: true)
    sign_in @teacher.user
    new_deadline = 3.days.from_now.change(sec: 0)

    get edit_organization_assignment_path(organizations(:one), assignment)
    assert_response :success
    assert_select "input[name='assignment[student_ids][]'][value='#{@student.id}'][checked]"
    assert_select "input[name='assignment[student_ids][]'][value='#{second_student.id}']:not([checked])"

    assert_enqueued_emails 2 do
      patch organization_assignment_path(organizations(:one), assignment), params: {
        assignment: {
          title: "Revised field notes",
          description: "Use the revised instructions.",
          deadline: new_deadline.strftime("%Y-%m-%dT%H:%M"),
          student_ids: [ @student.id, second_student.id ],
          remove_document: "1"
        }
      }
    end

    assignment.reload
    assert_redirected_to organization_assignment_path(organizations(:one), assignment)
    assert_equal "Revised field notes", assignment.title
    assert_equal "Use the revised instructions.", assignment.description
    assert_equal new_deadline, assignment.deadline
    assert_equal [ @student.id, second_student.id ].sort, assignment.student_membership_ids.sort
    assert_not assignment.document.attached?
    assert AuditEvent.exists?(action: "assignment.updated", auditable: assignment)
  end

  test "teacher cannot remove a student who has saved work" do
    second_student = create_member("student", "replacement-student@example.com", "Replacement Student")
    create_class_meeting(students: [ second_student ], subject: "Replacement")
    assignment = create_assignment
    assignment.recipients.find_by!(student_membership: @student).create_submission!(body: "Saved draft")
    sign_in @teacher.user

    patch organization_assignment_path(organizations(:one), assignment), params: {
      assignment: {
        title: assignment.title,
        description: assignment.description,
        deadline: assignment.deadline.strftime("%Y-%m-%dT%H:%M"),
        student_ids: [ second_student.id ]
      }
    }

    assert_response :unprocessable_entity
    assert_select ".alert-error", text: /Students with saved work cannot be removed/
    assert_equal [ @student.id ], assignment.reload.student_membership_ids
  end

  test "teacher cancels their assignment without deleting student work" do
    assignment = create_assignment
    submission = assignment.recipients.find_by!(student_membership: @student).create_submission!(body: "Saved draft")
    sign_in @teacher.user

    assert_enqueued_emails 1 do
      patch cancel_organization_assignment_path(organizations(:one), assignment)
    end

    assert_redirected_to organization_assignment_path(organizations(:one), assignment)
    assert assignment.reload.cancelled?
    assert_equal "Saved draft", submission.reload.body
    assert AuditEvent.exists?(action: "assignment.cancelled", auditable: assignment)

    sign_in @student.user
    get organization_assignment_path(organizations(:one), assignment)
    assert_response :success
    assert_select ".alert-error", text: /This assignment was cancelled/
    assert_select "form[action='#{organization_assignment_submission_path(organizations(:one), assignment)}']", count: 0

    patch organization_assignment_submission_path(organizations(:one), assignment), params: {
      assignment_submission: { body: "Changed after cancellation" }
    }
    assert_redirected_to root_path
    assert_equal "Saved draft", submission.reload.body
  end

  test "another teacher cannot edit or cancel the assignment" do
    other_teacher = create_member("teacher", "other-assignment-teacher@example.com", "Other Assignment Teacher")
    assignment = create_assignment
    sign_in other_teacher.user

    get edit_organization_assignment_path(organizations(:one), assignment)
    assert_response :not_found

    sign_in other_teacher.user
    patch cancel_organization_assignment_path(organizations(:one), assignment)
    assert_response :not_found
    assert_not assignment.reload.cancelled?
  end

  test "teacher can edit an overdue assignment without changing its deadline" do
    assignment = create_assignment
    original_deadline = 1.hour.ago
    assignment.update_column(:deadline, original_deadline)
    sign_in @teacher.user

    patch organization_assignment_path(organizations(:one), assignment), params: {
      assignment: {
        title: "Corrected field notes",
        description: assignment.description,
        deadline: original_deadline.in_time_zone(organizations(:one).timezone).strftime("%Y-%m-%dT%H:%M"),
        student_ids: [ @student.id ]
      }
    }

    assert_redirected_to organization_assignment_path(organizations(:one), assignment)
    assert_equal "Corrected field notes", assignment.reload.title
    assert_in_delta original_deadline, assignment.deadline, 0.001
  end

  test "teacher searches assignments by title or description" do
    matching = create_assignment
    other_assignment = organizations(:one).assignments.create!(
      teacher_membership: @teacher,
      title: "Reading response",
      description: "Respond to the assigned chapter.",
      deadline: 3.days.from_now,
      recipients: [ AssignmentRecipient.new(student_membership: @student) ]
    )
    sign_in @teacher.user

    get organization_assignments_path(organizations(:one), query: "field notes")

    assert_response :success
    assert_select "input[type='search'][name='query'][value='field notes']"
    assert_select "tr[data-assignment-id='#{matching.id}']", count: 1
    assert_select "tr[data-assignment-id='#{other_assignment.id}']", count: 0

    get organization_assignments_path(organizations(:one), query: "missing assignment")

    assert_response :success
    assert_select ".empty-state", text: /No assignments match/
    assert_select "a", text: "Clear"
  end

  private
    def create_assignment(document: false)
      assignment = organizations(:one).assignments.new(
        teacher_membership: @teacher,
        title: "Field notes",
        description: "Write a short summary of today's class.",
        deadline: 2.days.from_now
      )
      assignment.recipients.build(student_membership: @student)
      if document
        assignment.document.attach(io: file_fixture("assignment.txt").open, filename: "assignment.txt", content_type: "text/plain")
      end
      assignment.save!
      assignment
    end

    def create_class_meeting(students: [ @student ], subject: "Writing")
      meeting = organizations(:one).class_meetings.new(
        teacher_membership: @teacher,
        subject: subject,
        topic: "Field notes",
        starts_at: 1.day.ago,
        delivery_mode: "onsite"
      )
      meeting.student_memberships = students
      meeting.save!
    end

    def create_member(role_key, email, name)
      user = User.create!(name: name, email: email, password: "password", status: "active")
      membership = organizations(:one).memberships.create!(user: user, status: "active")
      membership.role_ids = [ organizations(:one).roles.find_by!(key: role_key).id ]
      membership
    end
end
