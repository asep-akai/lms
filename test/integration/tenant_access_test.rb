require "test_helper"

class TenantAccessTest < ActionDispatch::IntegrationTest
  test "organization administrator manages organization roles without console permissions" do
    role = organizations(:one).roles.find_by!(key: "student")
    course_permission = Permission.find_by!(key: "courses.create")

    sign_in users(:one)
    get organization_roles_path(organizations(:one))
    assert_response :success

    get edit_organization_role_path(organizations(:one), role)
    assert_response :success
    assert_select "legend", text: "Members"
    assert_select "legend", text: "Courses"
    assert_select "legend", text: "Administrators", count: 0
    assert_select "input[name='role[key]'][disabled]"
    assert_select "input[name='role[permission_ids][]'][value='#{course_permission.id}']"
    Permission::CONSOLE_ONLY_KEYS.each do |key|
      permission = Permission.find_by!(key: key)
      assert_select "input[name='role[permission_ids][]'][value='#{permission.id}']", count: 0
    end
  end

  test "organization administrator role is protected from editing" do
    admin_role = organizations(:one).roles.find_by!(key: "admin")
    original_name = admin_role.name

    sign_in users(:one)
    get organization_roles_path(organizations(:one))
    assert_response :success
    assert_select "tr", text: /Organization administrator.*Protected/m

    get edit_organization_role_path(organizations(:one), admin_role)
    assert_redirected_to root_path

    patch organization_role_path(organizations(:one), admin_role), params: {
      role: { name: "Restricted administrator", key: "admin", permission_ids: [] }
    }
    assert_redirected_to root_path
    assert_equal original_name, admin_role.reload.name
    assert_equal Permission.organization_assignable.order(:key).ids, admin_role.permissions.order(:key).ids
  end

  test "organization administrator creates a course and enrolls an existing student" do
    student_membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    student_membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]

    sign_in users(:one)

    assert_difference "Course.count", 1 do
      post organization_courses_path(organizations(:one)), params: {
        course: { name: "Introduction to Biology", description: "The foundations of biology." }
      }
    end

    course = Course.order(:created_at).last
    assert_redirected_to organization_course_path(organizations(:one), course)

    assert_difference "CourseEnrollment.count", 1 do
      patch enrollments_organization_course_path(organizations(:one), course), params: {
        course: { membership_ids: [ student_membership.id ] }
      }
    end

    assert_redirected_to organization_course_path(organizations(:one), course)
    assert_equal [ student_membership ], course.enrolled_memberships.reload
    event = AuditEvent.find_by!(action: "course.enrollments_updated", auditable: course)
    assert_equal(
      {
        "before" => [],
        "after" => [ "Student User (two@example.com)" ]
      },
      event.metadata.dig("changes", "enrolled_students")
    )
  end

  test "organization administrator records course field changes" do
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")

    sign_in users(:one)
    patch organization_course_path(organizations(:one), course), params: {
      course: { name: "Advanced Biology", description: "Cells and ecosystems." }
    }

    assert_redirected_to organization_course_path(organizations(:one), course)
    event = AuditEvent.find_by!(action: "course.updated", auditable: course)
    assert_equal(
      {
        "name" => { "before" => "Biology", "after" => "Advanced Biology" },
        "description" => { "before" => "Living systems.", "after" => "Cells and ecosystems." }
      },
      event.metadata.fetch("changes")
    )
  end

  test "organization administrator creates a quiz with supported question types" do
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")

    sign_in users(:one)

    assert_difference "Quiz.count", 1 do
      post organization_course_quizzes_path(organizations(:one), course), params: {
        quiz: { title: "Cells check-in", description: "A short formative assessment." }
      }
    end

    quiz = course.quizzes.find_by!(title: "Cells check-in")
    assert_redirected_to organization_course_quiz_path(organizations(:one), course, quiz)
    assert_difference "QuizQuestion.count", 1 do
      assert_difference "QuizAnswerOption.count", 2 do
        post organization_course_quiz_questions_path(organizations(:one), course, quiz), params: {
        quiz_question: {
          question_type: "multiple_choice",
          content_html: "<p>What is the basic unit of life?</p>",
          answer_options_attributes: {
            "0" => { content: "Cell", correct: "1" },
            "1" => { content: "Tissue", correct: "0" }
          }
        }
        }
      end
    end
    post organization_course_quiz_questions_path(organizations(:one), course, quiz), params: {
      quiz_question: { question_type: "short_answer", content_html: "<p>Name an organelle.</p>", short_answer: "Mitochondrion" }
    }
    assert_equal [ "multiple_choice", "short_answer" ], quiz.questions.pluck(:question_type)
    assert_equal [ 1, 2 ], quiz.questions.pluck(:position)
    assert_equal 1, quiz.questions.first.answer_options.count(&:correct?)
    assert AuditEvent.exists?(auditable: quiz, action: "quiz.created")
  end

  test "organization administrator creates material that an enrolled student can view" do
    student_membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    student_membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    course.course_enrollments.create!(membership: student_membership)

    sign_in users(:one)
    assert_difference "Material.count", 1 do
      post organization_course_materials_path(organizations(:one), course), params: {
        material: {
          title: "Cell structures",
          description: "An introduction to cell structures.",
          blocks_attributes: {
            "0" => { block_type: "text", body_html: "<p><strong>Cells</strong> contain organelles.</p>", position: 1 },
            "1" => { block_type: "text", body_html: "<p>They perform specialized functions.</p>", position: 2 }
          }
        }
      }
    end

    material = course.materials.find_by!(title: "Cell structures")
    assert_redirected_to organization_course_material_path(organizations(:one), course, material)
    assert AuditEvent.exists?(action: "material.created", auditable: material)

    sign_in users(:two)
    get organization_course_path(organizations(:one), course)
    assert_response :success
    assert_select "h3", "Cell structures"
    assert_select "p", "An introduction to cell structures."
    assert_select "p", { text: "Cells contain organelles.", count: 0 }
    assert_select "a", text: "View material"

    get organization_course_material_path(organizations(:one), course, material)
    assert_response :success
    assert_select "strong", "Cells"
    assert_select ".rich-content", count: 2
    assert_select "a", text: "Edit material", count: 0
  end

  test "grading lists attempts and keeps listing viewing and review permissions separate" do
    reviewer = User.create!(name: "Quiz Reviewer", email: "reviewer@example.com", password: "password", status: "active")
    reviewer_membership = organizations(:one).memberships.create!(user: reviewer, status: "active")
    reviewer_role = organizations(:one).roles.create!(name: "Attempt monitor", key: "attempt_monitor")
    reviewer_role.permissions = [ Permission.find_by!(key: "quiz_attempts.index") ]
    reviewer_membership.role_ids = [ reviewer_role.id ]

    student_membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    student_membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    course.course_enrollments.create!(membership: student_membership)
    quiz = course.quizzes.create!(title: "Cells check-in")
    question = quiz.questions.create!(question_type: "short_answer", content_html: "<p>Name an organelle.</p>", short_answer: "Mitochondrion", position: 1)
    attempt = QuizAttempt.create!(quiz: quiz, membership: student_membership, started_at: 1.hour.ago, last_activity_at: Time.current, submitted_at: Time.current)
    attempt.answers.create!(quiz_question: question, short_answer_response: "Mitochondrion")
    attempt.answer_overrides.create!(quiz_question: question, correct: false)
    older_quiz = course.quizzes.create!(title: "Earlier assessment")
    QuizAttempt.create!(quiz: older_quiz, membership: student_membership, started_at: 3.hours.ago, last_activity_at: 2.hours.ago)

    sign_in reviewer
    get organization_grading_path(organizations(:one))
    assert_response :success
    assert_select "tr", text: /Cells check-in.*Biology.*Student User.*Waiting for review/m
    assert_operator response.body.index("Cells check-in"), :<, response.body.index("Earlier assessment")
    assert_select "tr", text: /Cells check-in/ do
      assert_select ".attempt-score", text: "Not published"
      assert_select "time", text: /WIB\z/
    end
    assert_select "a", text: "View attempt", count: 0

    get organization_grading_path(organizations(:one), status: "waiting_for_review", query: "Cells")
    assert_response :success
    assert_select "input[type='hidden'][name='status'][value='waiting_for_review']"
    assert_select "input[type='search'][name='query'][value='Cells']"
    assert_select "tr", text: /Cells check-in/
    assert_select "td", text: "Earlier assessment", count: 0
    assert_select "nav[aria-label='Filter attempts'] a[href*='query=Cells']", minimum: 1

    get organization_grading_path(organizations(:one), status: "in_progress")
    assert_response :success
    assert_select "td", text: "Cells check-in", count: 0

    get organization_grading_attempt_path(organizations(:one), attempt)
    assert_redirected_to root_path

    reviewer_role.permissions << Permission.find_by!(key: "quiz_attempts.show")
    get organization_grading_attempt_path(organizations(:one), attempt)
    assert_response :success
    assert_select "h1", "Student User"
    assert_select "p", text: "Mitochondrion"
    assert_select "button", text: "Mark as reviewed", count: 0

    reviewer_role.permissions << Permission.find_by!(key: "quiz_attempts.review")
    patch organization_grade_answer_path(organizations(:one), attempt, question_id: question.id), params: { correct: "0" }
    assert_redirected_to organization_grading_attempt_path(organizations(:one), attempt, anchor: "question-#{question.id}")
    assert_not attempt.answer_overrides.find_by!(quiz_question: question).correct?

    get organization_grading_attempt_path(organizations(:one), attempt)
    assert_response :success
    assert_select "#score-heading", text: "0/1"
    assert_select "p", text: "0%"
    assert_select "span", text: "Manually graded"

    delete organization_reset_answer_grade_path(organizations(:one), attempt, question_id: question.id)
    assert_redirected_to organization_grading_attempt_path(organizations(:one), attempt, anchor: "question-#{question.id}")
    assert_empty attempt.answer_overrides.where(quiz_question: question)

    get organization_grading_attempt_path(organizations(:one), attempt)
    assert_response :success
    assert_select "#score-heading", text: "1/1"
    assert_select "span", text: "Manually graded", count: 0

    patch organization_grade_answer_path(organizations(:one), attempt, question_id: question.id), params: { correct: "1" }
    assert attempt.answer_overrides.find_by!(quiz_question: question).correct?

    patch organization_review_grading_attempt_path(organizations(:one), attempt)
    assert_redirected_to organization_grading_attempt_path(organizations(:one), attempt)
    assert_predicate attempt.reload, :reviewed?

    get organization_grading_path(organizations(:one), status: "reviewed")
    assert_response :success
    assert_select "tr", text: /Cells check-in.*Biology.*Student User.*Published/m
    assert_select "tr", text: /Cells check-in/ do
      assert_select ".attempt-score", text: /1\/1.*100%/m
    end

    patch organization_unreview_grading_attempt_path(organizations(:one), attempt)
    assert_redirected_to organization_grading_attempt_path(organizations(:one), attempt)
    assert_not attempt.reload.reviewed?
    assert_predicate attempt, :waiting_for_review?
    assert_predicate attempt, :submitted?

    delete organization_reset_grading_attempt_path(organizations(:one), attempt)
    assert_redirected_to root_path
    assert QuizAttempt.exists?(attempt.id)

    reviewer_role.permissions << Permission.find_by!(key: "quiz_attempts.reset")
    assert_difference "QuizAttempt.count", -1 do
      delete organization_reset_grading_attempt_path(organizations(:one), attempt)
    end
    assert_redirected_to organization_grading_path(organizations(:one))
    assert_not QuizAnswer.exists?(quiz_attempt_id: attempt.id)
    assert_not QuizAnswerOverride.exists?(quiz_attempt_id: attempt.id)
    assert AuditEvent.exists?(action: "quiz_attempt.reset", auditable_type: "QuizAttempt", auditable_id: attempt.id)

    sign_in users(:two)
    get organization_course_path(organizations(:one), course)
    assert_response :success
    assert_select "a", text: "View quiz"
    assert_select "#course-content-#{quiz.course_content.id}" do
      assert_select ".badge-neutral", text: "Not started"
      assert_select ".badge-active", text: "In progress", count: 0
    end

    get organization_course_quiz_path(organizations(:one), course, quiz, from: "course")
    assert_response :success
    assert_select "a", text: "Start quiz"
  end

  test "a reset attempt cannot be recreated by an already open quiz player" do
    student_membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    student_membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    course.course_enrollments.create!(membership: student_membership)
    quiz = course.quizzes.create!(title: "Cells check-in")
    question = quiz.questions.create!(question_type: "short_answer", content_html: "<p>Name an organelle.</p>", short_answer: "Mitochondrion", position: 1)
    attempt = QuizAttempt.create!(quiz: quiz, membership: student_membership, started_at: 1.hour.ago, last_activity_at: Time.current)

    sign_in users(:one)
    delete organization_reset_grading_attempt_path(organizations(:one), attempt)
    assert_not QuizAttempt.exists?(attempt.id)

    sign_in users(:two)
    assert_no_difference "QuizAttempt.count" do
      patch organization_course_quiz_attempt_answer_path(organizations(:one), course, quiz, question_id: question.id), params: {
        quiz_attempt_id: attempt.id,
        quiz_answer: { short_answer_response: "Mitochondrion" }
      }
    end
    assert_redirected_to organization_course_quiz_path(organizations(:one), course, quiz, from: "course")

    assert_no_difference "QuizAttempt.count" do
      get attempt_organization_course_quiz_path(organizations(:one), course, quiz, attempt_id: attempt.id)
    end
    assert_redirected_to organization_course_quiz_path(organizations(:one), course, quiz, from: "course")
  end

  test "AI grading creates an unpublished draft that an administrator confirms before students can see it" do
    student_membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    student_membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    course.course_enrollments.create!(membership: student_membership)
    quiz = course.quizzes.create!(title: "Cells check-in")
    question = quiz.questions.create!(question_type: "short_answer", content_html: "<p>Name an organelle.</p>", short_answer: "Mitochondrion", position: 1)
    attempt = QuizAttempt.create!(quiz: quiz, membership: student_membership, started_at: 1.hour.ago, last_activity_at: Time.current, submitted_at: Time.current)
    attempt.answers.create!(quiz_question: question, short_answer_response: "Mitochondrion")
    attempt.answer_overrides.create!(quiz_question: question, correct: false)
    sign_in users(:one)
    get organization_grading_path(organizations(:one))
    assert_response :success
    assert_select "a", text: "Manual grading"
    assert_select "button", text: "Automatic grading"
    assert_select "form[data-controller='blocking-submit'][data-action*='turbo:submit-start']"

    previous_api_key = ENV["GEMINI_API_KEY"]
    previous_model = ENV["GEMINI_MODEL"]
    ENV["GEMINI_API_KEY"] = "test-key"
    ENV["GEMINI_MODEL"] = "gemini-test"
    request = stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-test:generateContent")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          responseId: "response-123",
          candidates: [ {
            content: {
              parts: [ { text: {
                performance_analysis: "The answer demonstrates sound recall.",
                strengths: "Correctly identified the organelle.",
                weaknesses: "The response does not explain its function.",
                recommendations: "Review how mitochondria produce energy."
              }.to_json } ]
            }
          } ]
        }.to_json
      )
    begin
      post organization_automatic_grade_attempt_path(organizations(:one), attempt)
    ensure
      ENV["GEMINI_API_KEY"] = previous_api_key
      ENV["GEMINI_MODEL"] = previous_model
    end

    assert_redirected_to organization_grading_attempt_path(organizations(:one), attempt)
    assert_requested request
    assert_predicate attempt.reload, :waiting_for_confirmation?
    assert_not attempt.reviewed?
    assert_equal "ai", attempt.grading_mode
    assert_equal "The answer demonstrates sound recall.", attempt.performance_analysis
    assert_empty attempt.answer_overrides
    assert_equal 1, QuizAttemptGrader.new(attempt).correct_count

    get organization_grading_path(organizations(:one), status: "waiting_for_confirmation")
    assert_response :success
    assert_select "tr", text: /Cells check-in.*Waiting for confirmation/m

    sign_in users(:two)
    get organization_evaluation_attempt_path(organizations(:one), attempt)
    assert_redirected_to root_path

    sign_in users(:one)
    patch organization_review_grading_attempt_path(organizations(:one), attempt), params: {
      quiz_attempt: {
        performance_analysis: "Confirmed analysis.",
        recommendations: "Continue reviewing cell functions."
      }
    }
    assert_predicate attempt.reload, :reviewed?

    sign_in users(:two)
    get organization_evaluation_attempt_path(organizations(:one), attempt)
    assert_response :success
    assert_select "p", text: "Confirmed analysis."
    assert_select "p", text: "Continue reviewing cell functions."
  end

  test "organization administrator moves a quiz question between adjacent slots" do
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    quiz = course.quizzes.create!(title: "Cells check-in")
    first_question = quiz.questions.create!(question_type: "short_answer", content_html: "<p>First</p>", short_answer: "First", position: 1)
    second_question = quiz.questions.create!(question_type: "short_answer", content_html: "<p>Second</p>", short_answer: "Second", position: 2)

    sign_in users(:one)
    patch move_organization_course_quiz_question_path(organizations(:one), course, quiz, second_question, direction: "up")

    assert_redirected_to edit_organization_course_quiz_path(organizations(:one), course, quiz)
    assert_equal 2, first_question.reload.position
    assert_equal 1, second_question.reload.position
    assert_equal "quiz.question_reordered", AuditEvent.find_by!(auditable: quiz).action
  end

  test "member without quiz permission cannot access the editor" do
    course = organizations(:two).courses.create!(name: "Private course", description: "Enrollment is required.")
    course.course_enrollments.create!(membership: memberships(:two))

    sign_in users(:two)
    get new_organization_course_quiz_path(organizations(:two), course)

    assert_redirected_to root_path
  end

  test "student sees only courses in which they are enrolled" do
    student_membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    student_membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    enrolled_course = organizations(:one).courses.create!(name: "Enrolled course", description: "Visible to the student.")
    organizations(:one).courses.create!(name: "Other course", description: "Not visible to the student.")
    enrolled_course.course_enrollments.create!(membership: student_membership)

    sign_in users(:two)
    get organization_courses_path(organizations(:one))

    assert_response :success
    assert_select "h2", "Enrolled course"
    assert_select "h2", text: "Other course", count: 0
    assert_select "a", text: "New course", count: 0

    get organization_course_path(organizations(:one), enrolled_course)
    assert_response :success
    assert_select "h1", "Enrolled course"
    assert_select "a", text: "Edit course", count: 0
  end

  test "course page presents quizzes as course content" do
    student_membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    student_membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    course.course_enrollments.create!(membership: student_membership)
    quiz = course.quizzes.create!(title: "Cells check-in", description: "Review cell structure.")

    sign_in users(:two)
    get organization_course_path(organizations(:one), course)

    assert_response :success
    assert_select "section[aria-labelledby='course-content-heading']" do
      assert_select "h2", text: "Course content"
      assert_select "p", text: "Module 1 · Quiz"
      assert_select "h3", text: "Cells check-in"
      quiz_path = organization_course_quiz_path(organizations(:one), course, quiz, from: "course")
      assert_select "a[href='#{quiz_path}']", text: "View quiz"
      assert_select ".badge-neutral", text: "Not started"
      assert_select "button", text: "Move up", count: 0
      assert_select "button", text: "Move down", count: 0
    end
    assert_select "a", text: "View quizzes", count: 0
  end

  test "student progress and both administrator progress views use module completion" do
    student_membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    student_membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Biology progress", description: "Living systems.")
    course.course_enrollments.create!(membership: student_membership)
    material = course.materials.new(title: "Cell structure")
    material.blocks.build(block_type: "text", body_html: "<p>Cell structures.</p>", position: 1)
    material.save!
    quiz = course.quizzes.create!(title: "Cells check-in")

    sign_in users(:two)
    get organization_courses_path(organizations(:one))
    assert_response :success
    assert_select "a[href='#{organization_course_path(organizations(:one), course)}'] [role='progressbar'][aria-valuenow='0']"

    patch toggle_completion_organization_course_material_path(organizations(:one), course, material)
    assert_redirected_to organization_course_material_path(organizations(:one), course, material, from: "course")
    assert MaterialCompletion.exists?(membership: student_membership, material: material)

    patch toggle_completion_organization_course_material_path(organizations(:one), course, material)
    assert_redirected_to organization_course_material_path(organizations(:one), course, material, from: "course")
    assert_not MaterialCompletion.exists?(membership: student_membership, material: material)

    patch toggle_completion_organization_course_material_path(organizations(:one), course, material)
    assert MaterialCompletion.exists?(membership: student_membership, material: material)

    QuizAttempt.create!(
      quiz: quiz,
      membership: student_membership,
      started_at: Time.current,
      last_activity_at: Time.current,
      submitted_at: Time.current
    )
    get organization_course_path(organizations(:one), course)
    assert_response :success
    assert_select "[role='progressbar'][aria-label='Course completion'][aria-valuenow='100']"
    assert_select "p", text: "2 of 2 modules completed"
    assert_select "#course-content-#{material.course_content.id}", text: /Complete/
    assert_select "#course-content-#{quiz.course_content.id}", text: /Complete/

    sign_out :user
    sign_in users(:one)
    get organization_course_path(organizations(:one), course)
    assert_response :success
    assert_select "#student-progress-heading", text: "Student progress"
    assert_select "tr", text: /Student User.*100%.*2 \/ 2/m

    get organization_students_path(organizations(:one))
    assert_response :success
    assert_select "h1", text: "Students"
    assert_select "a[href='#{organization_student_path(organizations(:one), student_membership)}']", text: "View student"
    enrollment_path = enrollment_organization_student_path(organizations(:one), student_membership, modal: 1)
    assert_select "a[href='#{enrollment_path}']", text: "Enroll in course"

    get organization_student_path(organizations(:one), student_membership)
    assert_response :success
    assert_select "h1", text: "Student User"
    assert_select "section", text: /Biology progress.*2 of 2 modules completed.*100%/m
    assert_select "li", text: /Module 1 · Material.*Cell structure.*Complete/m
    assert_select "li", text: /Module 2 · Quiz.*Cells check-in.*Complete/m
  end

  test "organization administrator arranges materials and quizzes in one module sequence" do
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    first_material = course.materials.new(title: "Cell structure", description: "Read this first.")
    first_material.blocks.build(block_type: "text", body_html: "<p>Cell structures.</p>", position: 1)
    first_material.save!
    second_material = course.materials.new(title: "Cell function", description: "Read this second.")
    second_material.blocks.build(block_type: "text", body_html: "<p>Cell functions.</p>", position: 1)
    second_material.save!
    quiz = course.quizzes.create!(title: "Cells check-in")

    sign_in users(:one)
    get organization_course_path(organizations(:one), course)

    assert_response :success
    assert_operator response.body.index("Cell structure"), :<, response.body.index("Cell function")
    assert_operator response.body.index("Cell function"), :<, response.body.index("Cells check-in")
    assert_select "p", text: "Module 1 · Material"
    assert_select "p", text: "Module 2 · Material"
    assert_select "p", text: "Module 3 · Quiz"
    assert_select "button", text: "Move up"

    patch move_content_organization_course_path(
      organizations(:one),
      course,
      content_id: quiz.course_content.id,
      direction: "up"
    )

    assert_redirected_to organization_course_path(organizations(:one), course, anchor: "course-content-#{quiz.course_content.id}")
    assert_equal [ first_material, quiz, second_material ], course.course_contents.reload.map(&:contentable)
    assert AuditEvent.exists?(action: "course.content_reordered", auditable: course)
  end

  test "organization administrator manages sections and moves modules between them" do
    course = organizations(:one).courses.create!(name: "Sectioned biology", description: "Living systems.")
    first_section = course.default_section
    first_section.update!(name: "Foundations")
    material = course.materials.new(title: "Cell structure")
    material.blocks.build(block_type: "text", body_html: "<p>Cell structures.</p>", position: 1)
    material.save!

    sign_in users(:one)
    get new_organization_course_section_path(organizations(:one), course)
    assert_response :success
    assert_select "form[action='#{organization_course_sections_path(organizations(:one), course)}']"

    assert_difference "CourseSection.count", 1 do
      post organization_course_sections_path(organizations(:one), course), params: {
        course_section: { name: "Cell division" }
      }
    end
    second_section = course.course_sections.find_by!(name: "Cell division")
    assert_redirected_to organization_course_path(organizations(:one), course)

    get edit_organization_course_section_path(organizations(:one), course, second_section)
    assert_response :success
    assert_select "form[action='#{organization_course_section_path(organizations(:one), course, second_section)}']"

    patch organization_course_section_path(organizations(:one), course, second_section), params: {
      course_section: { name: "Cell reproduction" }
    }
    assert_redirected_to organization_course_path(organizations(:one), course, anchor: "course-section-#{second_section.id}")
    assert_equal "Cell reproduction", second_section.reload.name

    assert_difference "Quiz.count", 1 do
      post organization_course_quizzes_path(organizations(:one), course, from: "course"), params: {
        quiz: { title: "Mitosis check-in", description: "Review mitosis.", course_section_id: second_section.id }
      }
    end
    quiz = course.quizzes.find_by!(title: "Mitosis check-in")
    assert_equal second_section, quiz.course_content.course_section

    patch move_content_to_section_organization_course_path(
      organizations(:one),
      course,
      content_id: material.course_content.id
    ), params: { course_section_id: second_section.id }
    assert_redirected_to organization_course_path(organizations(:one), course, anchor: "course-content-#{material.course_content.id}")
    assert_equal second_section, material.course_content.reload.course_section
    assert_equal [ quiz, material ], second_section.course_contents.reload.map(&:contentable)

    patch move_organization_course_section_path(organizations(:one), course, second_section, direction: "up")
    assert_equal [ second_section, first_section ], course.course_sections.reload
  end

  test "submitted quiz attempt is shown as in review and cannot be reopened" do
    student_membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    student_membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    course.course_enrollments.create!(membership: student_membership)
    quiz = course.quizzes.create!(title: "Cells check-in")
    question = quiz.questions.create!(question_type: "short_answer", content_html: "<p>Name an organelle.</p>", short_answer: "Mitochondrion", position: 1)

    sign_in users(:two)
    get attempt_organization_course_quiz_path(organizations(:one), course, quiz)
    assert_response :success

    patch organization_course_quiz_attempt_answer_path(organizations(:one), course, quiz, question_id: question.id), params: {
      quiz_answer: { short_answer_response: "Mitochondrion" },
      submit_attempt: "Submit"
    }

    quiz_path = organization_course_quiz_path(organizations(:one), course, quiz, from: "course")
    assert_redirected_to quiz_path
    attempt = QuizAttempt.find_by!(quiz: quiz, membership: student_membership)
    assert_predicate attempt, :submitted?

    get attempt_organization_course_quiz_path(organizations(:one), course, quiz)
    assert_redirected_to quiz_path
    follow_redirect!
    assert_select "h2", text: "Attempt submitted"
    assert_select "nav[aria-label='Course module navigation']"
    assert_select "a[href='#{attempt_organization_course_quiz_path(organizations(:one), course, quiz)}']", count: 0

    get organization_course_path(organizations(:one), course)
    assert_response :success
    assert_select ".badge-suspended", text: "In review"
    assert_select "a[href='#{quiz_path}']", text: "View quiz"
  end

  test "enrolled student saves and resumes quiz answers" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    course.course_enrollments.create!(membership: membership)
    quiz = course.quizzes.create!(title: "Cells quiz")
    question = quiz.questions.create!(question_type: "short_answer", content_html: "<p>Name an organelle.</p>", short_answer: "Mitochondrion", position: 1)

    sign_in users(:two)
    get attempt_organization_course_quiz_path(organizations(:one), course, quiz)
    assert_response :success
    assert_difference "QuizAnswer.count", 1 do
      patch organization_course_quiz_attempt_answer_path(organizations(:one), course, quiz, question_id: question.id), params: {
        quiz_answer: { short_answer_response: "Mitochondrion" }
      }
    end
    assert_redirected_to organization_course_path(organizations(:one), course)

    get attempt_organization_course_quiz_path(organizations(:one), course, quiz)
    assert_response :success
    assert_select "textarea", text: "Mitochondrion"
    assert_equal 1, QuizAttempt.where(quiz: quiz, membership: membership).count
  end

  test "student evaluation exposes only their reviewed results" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    course.course_enrollments.create!(membership: membership)
    quiz = course.quizzes.create!(title: "Reviewed cells quiz")
    question = quiz.questions.create!(question_type: "short_answer", content_html: "<p>Name an organelle.</p>", short_answer: "Mitochondrion", position: 1)
    attempt = QuizAttempt.create!(quiz: quiz, membership: membership, started_at: 2.hours.ago, last_activity_at: 1.hour.ago, submitted_at: 1.hour.ago, reviewed_at: Time.current)
    attempt.answers.create!(quiz_question: question, short_answer_response: "Mitochondrion")
    attempt.answer_overrides.create!(quiz_question: question, correct: false)

    waiting_quiz = course.quizzes.create!(title: "Waiting cells quiz")
    waiting_attempt = QuizAttempt.create!(quiz: waiting_quiz, membership: membership, started_at: 1.hour.ago, last_activity_at: Time.current, submitted_at: Time.current)

    sign_in users(:two)
    get organization_evaluation_path(organizations(:one))
    assert_response :success
    assert_select "tr", text: /Reviewed cells quiz.*Biology.*0\/1.*0%/m
    assert_select "td", text: "Waiting cells quiz", count: 0

    get organization_evaluation_attempt_path(organizations(:one), attempt)
    assert_response :success
    assert_select "#evaluation-score-heading", text: "0/1"
    assert_select "span", text: "Wrong"
    assert_select "p", text: "Mitochondrion", minimum: 2
    assert_select "a[href='#{organization_evaluation_path(organizations(:one))}']", text: "Back to evaluation"

    get organization_course_path(organizations(:one), course)
    assert_response :success
    quiz_path = organization_course_quiz_path(organizations(:one), course, quiz, from: "course")
    assert_select "a[href='#{quiz_path}']", text: "View quiz"

    get quiz_path
    assert_response :success
    quiz_result_path = organization_evaluation_attempt_path(organizations(:one), attempt, from: "quiz")
    assert_select "a[href='#{quiz_result_path}']", text: "View results"

    get quiz_result_path
    assert_response :success
    assert_select "a[href='#{quiz_path}']", text: "Back to quiz"

    get organization_evaluation_attempt_path(organizations(:one), waiting_attempt)
    assert_redirected_to root_path
  end

  test "student can navigate backward from the final quiz question" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    course.course_enrollments.create!(membership: membership)
    quiz = course.quizzes.create!(title: "Cells quiz")
    questions = 4.times.map do |index|
      quiz.questions.create!(question_type: "short_answer", content_html: "<p>Question #{index + 1}</p>", short_answer: "Answer", position: index + 1)
    end

    sign_in users(:two)
    get attempt_organization_course_quiz_path(organizations(:one), course, quiz, question: 4)
    assert_response :success
    assert_select "button[name='next_question'][value='3']", "Previous"
    assert_select "nav[aria-label='Question navigation'] button[form='quiz-answer-form']", count: 3
    assert_select "nav[aria-label='Question navigation'] button[name='next_question'][value='3']", "3"
    assert_select "nav[aria-label='Question navigation'] button[aria-current='step'][disabled]", "4"
    assert_select "form[data-quiz-submit-unanswered-count-value='4']"

    get attempt_organization_course_quiz_path(organizations(:one), course, quiz)
    assert_response :success
    assert_select "p", text: /Question 4 of 4/

    patch organization_course_quiz_attempt_answer_path(organizations(:one), course, quiz, question_id: questions.last.id), params: {
      quiz_answer: { short_answer_response: "" }, next_question: 3
    }
    assert_redirected_to attempt_organization_course_quiz_path(organizations(:one), course, quiz, question: 3)
  end

  test "student can navigate away from an unanswered multiple choice question" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    course.course_enrollments.create!(membership: membership)
    quiz = course.quizzes.create!(title: "Cells quiz")
    first_question = quiz.questions.create!(question_type: "short_answer", content_html: "<p>First</p>", short_answer: "First", position: 1)
    multiple_choice = quiz.questions.build(question_type: "multiple_choice", content_html: "<p>Second</p>", position: 2)
    multiple_choice.answer_options.build(content: "Cell", correct: true)
    multiple_choice.answer_options.build(content: "Tissue", correct: false)
    multiple_choice.save!

    sign_in users(:two)
    get attempt_organization_course_quiz_path(organizations(:one), course, quiz)
    assert_response :success

    patch organization_course_quiz_attempt_answer_path(organizations(:one), course, quiz, question_id: multiple_choice.id, next_question: first_question.position), params: {
      quiz_answer: {}
    }

    assert_redirected_to attempt_organization_course_quiz_path(organizations(:one), course, quiz, question: first_question.position)
    assert_equal 0, QuizAnswer.count
  end

  test "student cannot view an unenrolled course" do
    student_membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    student_membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Private course", description: "Enrollment is required.")

    sign_in users(:two)
    get organization_course_path(organizations(:one), course)

    assert_redirected_to root_path
  end

  test "dashboard redirects a member with one organization into that organization" do
    sign_in users(:one)
    get root_path

    assert_redirected_to organization_path(organizations(:one))
  end

  test "dashboard lets a member with multiple organizations choose one" do
    membership = organizations(:two).memberships.create!(user: users(:one), status: "active")
    membership.role_ids = [ organizations(:two).roles.find_by!(key: "teacher").id ]

    sign_in users(:one)
    get root_path

    assert_response :success
    assert_select "h2", text: organizations(:one).name
    assert_select "h2", text: organizations(:two).name
    assert_select ".card-link", text: /Organization administrator/
    assert_select ".card-link", text: /Teacher/
  end

  test "organization directory works as a direct entry URL" do
    membership = organizations(:two).memberships.create!(user: users(:one), status: "active")
    membership.role_ids = [ organizations(:two).roles.find_by!(key: "teacher").id ]

    sign_in users(:one)
    host! "0.0.0.0:3001"
    get organizations_path

    assert_response :success
    assert_select "h2", text: organizations(:one).name
    assert_select "h2", text: organizations(:two).name
    assert_select ".card-link", text: /Organization administrator/
    assert_select ".card-link", text: /Teacher/
  end

  test "organization dashboard hides a student's role and management controls" do
    sign_in users(:two)
    get organization_path(organizations(:two))

    assert_response :success
    assert_select "h2", { text: "Your roles", count: 0 }
    assert_select "p", { text: "Student", count: 0 }
    assert_select "a", text: "Manage users", count: 0
    assert_select ".stat-label", text: "Users", count: 0
  end

  test "organization dashboard hides a teacher's role" do
    teacher = User.create!(name: "Dashboard Teacher", email: "dashboard-teacher@example.com", password: "password", status: "active")
    membership = organizations(:one).memberships.create!(user: teacher, status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "teacher").id ]

    sign_in teacher
    get organization_path(organizations(:one))

    assert_response :success
    assert_select "h2", { text: "Your roles", count: 0 }
    assert_select "p", { text: "Teacher", count: 0 }
  end

  test "organization dashboard identifies an administrator's role and management controls" do
    sign_in users(:one)
    get organization_path(organizations(:one))

    assert_response :success
    assert_select "section[aria-labelledby='your-roles-heading']", text: /Organization administrator/
    assert_select "a", text: "Manage users"
    assert_select "a", text: "View student progress"
    assert_select ".stat-label", text: "Users"
  end

  test "member cannot access another organization" do
    sign_in users(:one)
    get organization_memberships_path(organizations(:two))
    assert_redirected_to root_path
  end

  test "suspended organization is excluded and direct access explains why" do
    organization = organizations(:two)
    organization.update!(status: "suspended")
    sign_in users(:two)

    get root_path
    assert_response :success
    assert_select "h2", text: organization.name, count: 0

    get organization_path(organization)
    assert_redirected_to root_path
    follow_redirect!
    assert_select ".alert-error", "This organization is suspended and cannot be accessed."
  end

  test "organization pages opt out of Turbo caching" do
    sign_in users(:one)
    get organization_path(organizations(:one))

    assert_response :success
    assert_select "meta[name='turbo-cache-control'][content='no-cache']", count: 1
  end

  test "member without permission cannot manage roles" do
    sign_in users(:two)
    get organization_roles_path(organizations(:two))
    assert_redirected_to root_path
  end

  test "role form can render inside the modal frame" do
    role_manager = User.create!(
      name: "Role Manager",
      email: "role-manager@example.com",
      password: "password",
      password_confirmation: "password"
    )
    membership = organizations(:one).memberships.create!(user: role_manager, status: "active")
    role = organizations(:one).roles.create!(name: "Role manager", key: "role_manager")
    role.permissions = Permission.where(key: %w[roles.create])
    membership.role_ids = [ role.id ]

    sign_in role_manager
    get new_organization_role_path(organizations(:one), modal: 1), headers: { "Turbo-Frame" => "modal" }
    assert_response :success
    assert_includes response.body, '<turbo-frame id="modal">'
    assert_not_includes response.body, "<!DOCTYPE html>"
    assert_select "form[data-turbo-frame='_top']", count: 1
  end

  test "organization administrator can invite a new member" do
    sign_in users(:one)
    role = organizations(:one).roles.find_by!(key: "teacher")

    assert_difference [ "User.count", "Membership.count" ], 1 do
      post organization_memberships_path(organizations(:one)), params: {
        membership: {
          name: "Invited Teacher", email: "teacher@example.com", role_ids: [ role.id ],
          password: "initial-password", password_confirmation: "initial-password"
        }
      }
    end

    assert_redirected_to organization_memberships_path(organizations(:one))
    user = User.find_by!(email: "teacher@example.com")
    assert user.invited_at.present?
    assert user.valid_password?("initial-password")
  end

  test "organization administrator can open the new member form" do
    sign_in users(:one)

    get new_organization_membership_path(organizations(:one))

    assert_response :success
    assert_select "form"
    assert_select "input[name='membership[role_ids][]']", minimum: 3
  end

  test "organization administrator can assign and change administrator roles" do
    admin_role = organizations(:one).roles.find_by!(key: "admin")
    teacher_role = organizations(:one).roles.find_by!(key: "teacher")

    sign_in users(:one)
    post organization_memberships_path(organizations(:one)), params: {
      membership: {
        name: "Second Administrator",
        email: "second-admin@example.com",
        password: "initial-password",
        password_confirmation: "initial-password",
        role_ids: [ admin_role.id ]
      }
    }

    membership = organizations(:one).memberships.joins(:user).find_by!(users: { email: "second-admin@example.com" })
    assert_redirected_to organization_memberships_path(organizations(:one))
    assert_predicate membership, :organization_admin?

    patch organization_membership_path(organizations(:one), membership), params: {
      membership: { status: "active", role_ids: [ teacher_role.id ], password: "", password_confirmation: "" }
    }

    assert_redirected_to organization_memberships_path(organizations(:one))
    assert_equal [ teacher_role ], membership.roles.reload
  end

  test "custom membership managers cannot grant or manage organization administrators" do
    manager = User.create!(
      name: "Membership Manager",
      email: "membership-manager@example.com",
      password: "password",
      password_confirmation: "password"
    )
    manager_membership = organizations(:one).memberships.create!(user: manager, status: "active")
    manager_role = organizations(:one).roles.create!(name: "Membership manager", key: "membership_manager")
    manager_role.permissions = Permission.where(key: %w[memberships.index memberships.create memberships.update memberships.destroy])
    manager_membership.role_ids = [ manager_role.id ]
    admin_role = organizations(:one).roles.find_by!(key: "admin")

    sign_in manager
    get new_organization_membership_path(organizations(:one))
    assert_response :success
    assert_select "input[name='membership[role_ids][]'][value='#{admin_role.id}']", count: 0
    assert_select "p", text: "Only organization administrators can assign the administrator role."

    assert_no_difference [ "User.count", "Membership.count" ] do
      post organization_memberships_path(organizations(:one)), params: {
        membership: {
          name: "Unauthorized Administrator",
          email: "unauthorized-admin@example.com",
          password: "initial-password",
          password_confirmation: "initial-password",
          role_ids: [ admin_role.id ]
        }
      }
    end
    assert_redirected_to root_path

    get edit_organization_membership_path(organizations(:one), memberships(:one))
    assert_redirected_to root_path
    delete organization_membership_path(organizations(:one), memberships(:one))
    assert_redirected_to root_path
    assert Membership.exists?(memberships(:one).id)
  end

  test "student tracking permissions are separate from user management" do
    viewer = User.create!(
      name: "Progress Viewer",
      email: "progress-viewer@example.com",
      password: "password",
      password_confirmation: "password"
    )
    viewer_membership = organizations(:one).memberships.create!(user: viewer, status: "active")
    viewer_role = organizations(:one).roles.create!(name: "Progress viewer", key: "progress_viewer")
    viewer_role.permissions = Permission.where(key: %w[students.index students.show])
    viewer_membership.role_ids = [ viewer_role.id ]
    student = organizations(:one).memberships.create!(user: users(:two), status: "active")
    student.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]

    sign_in viewer
    get organization_students_path(organizations(:one))
    assert_response :success
    assert_select "a[href='#{organization_student_path(organizations(:one), student)}']", text: "View student"
    assert_select "a", text: "Enroll in course", count: 0
    assert_select "a[href='#{organization_memberships_path(organizations(:one))}']", count: 0

    get organization_student_path(organizations(:one), student)
    assert_response :success
    assert_select "form[action='#{enroll_organization_student_path(organizations(:one), student)}']", count: 0

    post enroll_organization_student_path(organizations(:one), student), params: { course_id: organizations(:one).courses.create!(name: "Private", description: "Private course.").id }
    assert_redirected_to root_path

    get organization_memberships_path(organizations(:one))
    assert_redirected_to root_path
  end

  test "organization administrator enrolls a student from a dedicated modal" do
    student = organizations(:one).memberships.create!(user: users(:two), status: "active")
    student.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    existing_course = organizations(:one).courses.create!(name: "Existing course", description: "Already enrolled.")
    available_course = organizations(:one).courses.create!(name: "Available course", description: "Open for enrollment.")
    existing_course.course_enrollments.create!(membership: student)

    sign_in users(:one)
    get organization_student_path(organizations(:one), student)
    assert_response :success
    assert_select "form[action='#{enroll_organization_student_path(organizations(:one), student)}']", count: 0

    get enrollment_organization_student_path(organizations(:one), student, modal: 1), headers: { "Turbo-Frame" => "modal" }
    assert_response :success
    assert_select "turbo-frame#modal"
    assert_select "select[name='course_id'] option[value='#{existing_course.id}']", count: 0
    assert_select "select[name='course_id'] option[value='#{available_course.id}']", text: "Available course"

    assert_difference "CourseEnrollment.count", 1 do
      post enroll_organization_student_path(organizations(:one), student), params: { course_id: available_course.id }
    end

    assert_redirected_to organization_students_path(organizations(:one))
    assert available_course.course_enrollments.exists?(membership: student)
    event = AuditEvent.find_by!(action: "course.enrollments_updated", auditable: available_course)
    assert_equal 1, event.metadata["enrollment_count"]

    get enrollment_organization_student_path(organizations(:one), student)
    assert_response :success
    assert_select "select[name='course_id']", count: 0
    assert_select ".empty-state", text: "This student is already enrolled in every available course."
  end

  test "organization cannot lose its final active administrator" do
    sign_in users(:one)
    membership = memberships(:one)
    admin_role = organizations(:one).roles.find_by!(key: "admin")

    patch organization_membership_path(organizations(:one), membership), params: {
      membership: { status: "suspended", role_ids: [ admin_role.id ] }
    }

    assert_response :unprocessable_entity
    assert membership.reload.active?
  end

  test "organization administrator replaces a member password without seeing the current password" do
    sign_in users(:one)
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]

    get edit_organization_membership_path(organizations(:one), membership)
    assert_response :success
    assert_select "input[type='password'][name='membership[password]']", count: 1
    assert_select "input[type='password'][name='membership[password]'][value]", count: 0

    patch organization_membership_path(organizations(:one), membership), params: {
      membership: {
        status: membership.status, role_ids: membership.role_ids,
        password: "replacement-password", password_confirmation: "replacement-password"
      }
    }

    assert_redirected_to organization_memberships_path(organizations(:one))
    assert membership.user.reload.valid_password?("replacement-password")
    assert AuditEvent.exists?(action: "membership.user_password_changed", auditable: membership)
  end

  test "organization administrator records membership status and role changes" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    student_role = organizations(:one).roles.find_by!(key: "student")
    teacher_role = organizations(:one).roles.find_by!(key: "teacher")
    membership.role_ids = [ student_role.id ]

    sign_in users(:one)
    patch organization_membership_path(organizations(:one), membership), params: {
      membership: { status: "suspended", role_ids: [ teacher_role.id ], password: "", password_confirmation: "" }
    }

    assert_redirected_to organization_memberships_path(organizations(:one))
    event = AuditEvent.find_by!(action: "membership.updated", auditable: membership)
    assert_equal({ "before" => "active", "after" => "suspended" }, event.metadata.dig("changes", "status"))
    assert_equal({ "before" => [ "Student" ], "after" => [ "Teacher" ] }, event.metadata.dig("changes", "roles"))
  end

  test "organization audit log presents readable event details" do
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    AuditRecorder.record!(
      action: "course.enrollments_updated",
      auditable: course,
      organization: organizations(:one),
      actor: users(:one),
      metadata: { enrollment_count: 2 },
      changes: { enrolled_students: [ [], [ "Student User (two@example.com)" ] ] }
    )

    sign_in users(:one)
    get organization_audit_events_path(organizations(:one))

    assert_response :success
    assert_select "strong", "Updated course enrollments"
    assert_select "td", text: /one@example.com/
    assert_select "td", text: /Organization member/
    assert_select "td", text: /Biology/
    assert_select "summary", "View details"
    assert_select "th", "Changed field"
    assert_select "th", "Before"
    assert_select "th", "After"
    assert_select "td", text: /Student User \(two@example.com\)/
    assert_select "dd", "2"
  end

  test "organization audit log explains when no events exist" do
    AuditEvent.where(organization: organizations(:one)).delete_all

    sign_in users(:one)
    get organization_audit_events_path(organizations(:one))

    assert_response :success
    assert_select "h2", "No audit events yet"
    assert_select "p", text: /events will appear here as activity occurs/
  end
end
