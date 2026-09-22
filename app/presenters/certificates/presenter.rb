module Certificates
  class Presenter
    PRESENTERS = {
      "exam_result" => Certificates::ExamResultPresenter
    }.freeze

    def self.for(certificate)
      PRESENTERS.fetch(certificate.certificate_type).new(certificate)
    end
  end
end
