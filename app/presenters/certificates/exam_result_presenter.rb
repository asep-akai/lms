module Certificates
  class ExamResultPresenter
    attr_reader :certificate

    def initialize(certificate)
      @certificate = certificate
      @data = certificate.data.with_indifferent_access
    end

    def heading = "Certificate of exam result"
    def exam_name = @data.fetch(:exam_name)
    def student_name = @data.fetch(:student_name)
    def test_date = Date.iso8601(@data.fetch(:test_date))
    def score = @data.fetch(:score)
    def percentage = @data.fetch(:percentage)
    def analysis = @data.fetch(:analysis)

    def filename
      "#{student_name.parameterize}-#{exam_name.parameterize}-certificate.pdf"
    end
  end
end
