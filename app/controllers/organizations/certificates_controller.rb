class Organizations::CertificatesController < Organizations::BaseController
  before_action :set_certificate, only: %i[show unpublish]

  def index
    authorize Certificate
    @query = TableSearch.normalize(params[:query])
    certificates = policy_scope(Certificate).joins(recipient_membership: :user)
    @certificates = TableSearch.call(
      certificates,
      query: @query,
      columns: [ "certificates.certificate_type", "CAST(certificates.data AS text)", "users.name", "users.email" ]
    )
      .includes(recipient_membership: :user, unpublished_by_membership: :user)
      .newest_first
  end

  def create
    attempt = policy_scope(QuizAttempt)
      .includes(membership: :user, quiz: [ :course, { questions: :answer_options } ], answers: :quiz_answer_option, answer_overrides: [])
      .find(params[:attempt_id])
    authorize Certificate.new(source: attempt), :create?

    existing_certificate = attempt.result_certificate
    certificate = Certificates::Generate.call(source: attempt, issued_by: Current.membership)
    unless existing_certificate
      AuditRecorder.record!(
        action: "certificate.generated",
        auditable: certificate,
        metadata: { certificate_type: certificate.certificate_type, exam: attempt.quiz.title, student: attempt.membership.user.name }
      )
    end

    redirect_to organization_certificate_path(Current.organization, certificate, from: "grading"),
      notice: existing_certificate ? "Certificate was already generated." : "Certificate generated."
  rescue ArgumentError => error
    redirect_to organization_grading_attempt_path(Current.organization, params[:attempt_id]), alert: error.message
  end

  def show
    authorize @certificate
    @presenter = Certificates::Presenter.for(@certificate)
    set_back_destination

    respond_to do |format|
      format.html
      format.pdf do
        authorize @certificate, :download?
        pdf = Certificates::PdfRenderer.call(@certificate)
        downloading = params[:download] == "1"
        response.headers["Cache-Control"] = "private, no-store"
        response.headers["Content-Length"] = pdf.bytesize.to_s
        response.headers["Content-Transfer-Encoding"] = "binary"
        send_data pdf,
          filename: @presenter.filename,
          type: downloading ? "application/octet-stream" : "application/pdf",
          disposition: downloading ? "attachment" : "inline"
      end
    end
  end

  def unpublish
    authorize @certificate, :unpublish?
    @certificate.unpublish!(by: Current.membership)
    AuditRecorder.record!(
      action: "certificate.unpublished",
      auditable: @certificate,
      metadata: {
        certificate_type: @certificate.certificate_type,
        exam: @certificate.data["exam_name"],
        student: @certificate.data["student_name"]
      }
    )

    redirect_to organization_certificate_path(Current.organization, @certificate, from: params[:from]),
      notice: "Certificate unpublished. You can now generate a new certificate from the grading page."
  rescue ArgumentError => error
    redirect_to organization_certificate_path(Current.organization, @certificate, from: params[:from]), alert: error.message
  end

  private
    def set_certificate
      @certificate = policy_scope(Certificate)
        .includes(:organization, recipient_membership: :user, unpublished_by_membership: :user)
      .find(params[:id])
    end

    def set_back_destination
      if params[:from] == "grading" && policy(@certificate.source).show?
        @back_label = "Back to grading"
        @back_path = organization_grading_attempt_path(Current.organization, @certificate.source)
      elsif params[:from] == "evaluation" && policy(@certificate.source).result?
        @back_label = "Back to evaluation"
        @back_path = organization_evaluation_attempt_path(Current.organization, @certificate.source)
      elsif params[:from] == "student" && StudentPolicy.new(current_user, @certificate.recipient_membership).show?
        @back_label = "Back to student"
        @back_path = organization_student_path(Current.organization, @certificate.recipient_membership)
      else
        @back_label = "Back to certificates"
        @back_path = organization_certificates_path(Current.organization)
      end
    end
end
