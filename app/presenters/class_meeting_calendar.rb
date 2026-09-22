class ClassMeetingCalendar
  attr_reader :month_start, :today

  def initialize(scope:, month:, time_zone:, today: Time.current)
    @time_zone = ActiveSupport::TimeZone[time_zone]
    @today = today.in_time_zone(@time_zone).to_date
    @month_start = parse_month(month) || @today.beginning_of_month
    @grid_start = @month_start.beginning_of_week(:monday)
    @grid_end = @month_start.end_of_month.end_of_week(:monday)
    @meetings_by_date = load_meetings(scope).group_by { |meeting| local_date(meeting.starts_at) }
  end

  def weeks = (@grid_start..@grid_end).each_slice(7).to_a
  def meetings_on(date) = @meetings_by_date.fetch(date, [])
  def month_label = @month_start.strftime("%B %Y")
  def month_key = @month_start.strftime("%Y-%m")
  def previous_month_key = (@month_start - 1.month).strftime("%Y-%m")
  def next_month_key = (@month_start + 1.month).strftime("%Y-%m")
  def current_month? = @month_start == @today.beginning_of_month
  def in_month?(date) = date.month == @month_start.month && date.year == @month_start.year
  def today?(date) = date == @today
  def total_count
    month_end = @month_start.end_of_month
    @meetings_by_date.sum { |date, meetings| date.between?(@month_start, month_end) ? meetings.size : 0 }
  end

  private
    def parse_month(value)
      return unless value.to_s.match?(/\A\d{4}-\d{2}\z/)

      Date.strptime("#{value}-01", "%Y-%m-%d").beginning_of_month
    rescue Date::Error
      nil
    end

    def load_meetings(scope)
      scope
        .where(starts_at: local_start(@grid_start)...local_start(@grid_end + 1.day))
        .includes(teacher_membership: :user, student_memberships: :user)
        .chronological
        .to_a
    end

    def local_start(date)
      @time_zone.local(date.year, date.month, date.day).utc
    end

    def local_date(timestamp)
      timestamp.in_time_zone(@time_zone).to_date
    end
end
