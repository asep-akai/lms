require "prawn"

module Certificates
  class ExamResultPdf
    NAVY = "183153"
    BLUE = "315B86"
    PALE_BLUE = "EAF1F7"
    INK = "172033"
    MUTED = "596579"
    RULE = "CBD5E1"

    def initialize(certificate)
      @certificate = certificate
      @presenter = Certificates::Presenter.for(certificate)
    end

    def render
      document = Prawn::Document.new(
        page_size: "A4",
        margin: [ 54, 54, 70, 54 ],
        info: {
          Title: @presenter.heading,
          Author: @certificate.organization.name,
          Subject: @presenter.exam_name
        }
      )
      add_page_frame(document)
      add_footer(document)
      document.move_down 18
      document.indent(18, 18) do
        add_header(document)
        add_recipient(document)
        add_results(document)
        add_analysis(document)
      end
      document.number_pages "Page <page> of <total>", at: [ document.bounds.right - 72, -24 ], width: 72,
        align: :right, size: 8, color: MUTED
      document.render
    end

    private
      def add_page_frame(document)
        document.repeat(:all) do
          document.stroke_color BLUE
          document.line_width 1.5
          document.stroke_bounds
        end
      end

      def add_header(document)
        document.fill_color NAVY
        document.text @presenter.heading.upcase, size: 10, character_spacing: 1.5, style: :bold
        document.move_down 8
        document.text @certificate.organization.name, size: 24, style: :bold
        document.move_down 8
        document.stroke_color RULE
        document.stroke_horizontal_rule
        document.move_down 30
      end

      def add_recipient(document)
        document.fill_color MUTED
        document.text "This certifies the published result of", size: 11, align: :center
        document.move_down 12
        document.fill_color INK
        document.text @presenter.student_name, size: 28, style: :bold, align: :center
        document.move_down 12
        document.fill_color MUTED
        document.text "for the examination", size: 11, align: :center
        document.move_down 8
        document.fill_color NAVY
        document.text @presenter.exam_name, size: 18, style: :bold, align: :center
        document.move_down 32
      end

      def add_results(document)
        box_width = (document.bounds.width - 24) / 3.0
        results = [
          [ "Test date", @presenter.test_date.strftime("%-d %B %Y") ],
          [ "Score", @presenter.score ],
          [ "Percentage", @presenter.percentage.nil? ? "—" : "#{@presenter.percentage}%" ]
        ]

        document.bounding_box([ 0, document.cursor ], width: document.bounds.width, height: 72) do
          results.each_with_index do |(label, value), index|
            document.bounding_box([ index * (box_width + 12), 72 ], width: box_width, height: 72) do
              document.fill_color PALE_BLUE
              document.fill_rectangle [ 0, 72 ], box_width, 72
              document.fill_color MUTED
              document.text_box label, at: [ 12, 57 ], width: box_width - 24, height: 14, size: 9
              document.fill_color INK
              document.text_box value.to_s, at: [ 12, 35 ], width: box_width - 24, height: 24, size: 15, style: :bold
            end
          end
        end
        document.move_down 28
      end

      def add_analysis(document)
        document.fill_color NAVY
        document.text "PERFORMANCE ANALYSIS", size: 10, character_spacing: 1.2, style: :bold
        document.move_down 10
        document.fill_color INK
        document.text @presenter.analysis, size: 11, leading: 5
      end

      def add_footer(document)
        generated_label = "Generated #{@certificate.generated_at.in_time_zone(@certificate.organization.timezone).strftime('%-d %B %Y at %H:%M %Z')} | Certificate ID: #{@certificate.id}"
        document.repeat(:all) do
          document.draw_text generated_label, at: [ 0, -24 ], size: 8, color: MUTED
        end
      end
  end
end
