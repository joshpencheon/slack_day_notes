require 'active_support/all'
require 'chronic'

class Post
  DAY_SPLITTER_REGEXP = /^[\{\[](?<dateref>[^\]\}]*?)[\}\]]\s*(?<body>.*)/m

  attr_accessor :date, :user, :message

  def initialize(date, user, message)
    @date = date.to_date
    @user = user
    @message = message
  end

  def split_by_day
    historic_lines, today_lines = historic_and_current_message_lines

    day_slices = day_slices_for(historic_lines, today_lines)

    dated_fragments_for(day_slices).map do |date, body_fragments|
      Post.new(date, user, body_fragments.reverse.join("\n"))
    end
  end

  private

  def historic_and_current_message_lines
    chunks = message.lines.chunk { |line| day_splitter?(line) }.to_a

    if (splitter, recent_lines = chunks.last) && !splitter
      historic_lines = chunks[0..-2].flat_map { |_, lines| lines }
      today_lines = recent_lines
    else
      historic_lines = chunks.flat_map { |_, lines| lines }
      today_lines = []
    end

    [historic_lines, today_lines]
  end

  def day_slices_for(historic_lines, today_lines)
    day_slices = historic_lines.slice_when do |line_a, line_b|
      day_splitter?(line_b)
    end.to_a

    day_slices << today_lines if today_lines.any?
    day_slices
  end

  def dated_fragments_for(day_slices)
    fragments_by_day = Hash.new { |hash, key| hash[key] = [] }
    today = date

    day_slices.reverse.each do |lines|
      dateref, body = extract_date_from(lines)
      post_date = relative_date(today, dateref)
      today = post_date # parse next chunks relatively
      fragments_by_day[post_date] << body
    end

    fragments_by_day
  end

  # Does the current message line explicitly reference
  # a particular day?
  def day_splitter?(line)
    line.match?(DAY_SPLITTER_REGEXP)
  end

  def extract_date_from(lines)
    message = lines.map(&:strip).join("\n")
    match = message.match(DAY_SPLITTER_REGEXP)

    if match
      [match[:dateref], match[:body]]
    else
      [nil, message]
    end
  end

  def relative_date(today, dateref)
    return today if dateref.nil?

    relative = Chronic.parse(dateref, now: today, context: :past).to_date
    return relative unless today - 1.week >= relative

    # If we're jumping more than a week, parse relative to tomorrow
    # so e.g. today's day means today rather than a week ago
    Chronic.parse(dateref, now: today + 1.day, context: :past).to_date
  rescue
    today
  end
end
