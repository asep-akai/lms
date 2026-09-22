module Certificates
  class QuizAttemptBuilder
    CERTIFICATE_TYPE = "exam_result"

    def initialize(attempt)
      @attempt = attempt
    end

    def attributes
      raise ArgumentError, "Quiz results must be published before generating a certificate" unless @attempt.reviewed?

      organization = @attempt.quiz.course.organization
      grading = QuizAttemptGrader.new(@attempt)
      {
        certificate_type: CERTIFICATE_TYPE,
        organization: organization,
        recipient_membership: @attempt.membership,
        data: {
          "exam_name" => @attempt.quiz.title,
          "student_name" => @attempt.membership.user.name,
          "test_date" => @attempt.submitted_at.in_time_zone(organization.timezone).to_date.iso8601,
          "score" => "#{grading.correct_count}/#{grading.total_count}",
          "percentage" => grading.percentage,
          "analysis" => @attempt.performance_analysis.to_s.strip.presence || "No performance analysis was provided."
        }
      }
    end
  end
end
