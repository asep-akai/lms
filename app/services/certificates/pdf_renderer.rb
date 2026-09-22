module Certificates
  class PdfRenderer
    RENDERERS = {
      "exam_result" => Certificates::ExamResultPdf
    }.freeze

    def self.call(certificate)
      RENDERERS.fetch(certificate.certificate_type).new(certificate).render
    end
  end
end
