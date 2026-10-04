class LandingSectionBackgrounds
  STYLES = %w[cream sage forest].freeze
  DEFAULTS = { "hero" => "cream", "story" => "cream", "features" => "forest", "roadmap" => "sage", "contact" => "forest" }.freeze

  def self.resolve(sections)
    sections.each_with_index.each_with_object([]) do |(section, index), resolved|
      style = section["background_style"]
      unless STYLES.include?(style)
        neighbors = [ resolved.last&.fetch("resolved_background_style"), sections[index + 1]&.fetch("background_style", nil) ]
        candidates = [ DEFAULTS.fetch(section["layout"], "cream"), *STYLES ].uniq
        style = candidates.find { |candidate| !neighbors.include?(candidate) }
      end
      resolved << section.merge("resolved_background_style" => style)
    end
  end
end
