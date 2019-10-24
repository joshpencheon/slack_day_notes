require 'active_support/all'
require 'chronic'

class Post
  DAY_SPLITTER_REGEXP = /^[\{\[](?<dateref>\w+?)[\}\]]\s*(?<body>.*)/m

  attr_accessor :date, :user, :message

  def initialize(date, user, message)
    @date = date.to_date
    @user = user
    @message = message
  end

  def split_posts
    chunks = message.lines.chunk { |line| day_splitter?(line) }.to_a

    if (splitter, recent_lines = chunks.last) && !splitter
      historic_lines = chunks[0..-2].flat_map { |_, lines| lines }
      today_lines = recent_lines
    else
      historic_lines = chunks.flat_map { |_, lines| lines }
      today_lines = []
    end

    day_slices = historic_lines.slice_when do |line_a, line_b|
      day_splitter?(line_b)
    end.to_a

    day_slices << today_lines if today_lines.any?

    today = date

    day_slices.reverse.map do |lines|
      dateref, body = extract_date_from(lines)
      post_time = relative_time(today, dateref)
      today = post_time # parse next chunks relatively
      Post.new(post_time, user, body)
    end
  end

  private

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

  def relative_time(today, dateref)
    return today if dateref.nil?

    relative = Chronic.parse(dateref, now: today, context: :past).to_date
    return relative unless today - 1.week >= relative

    # If we're jumping more than a week, parse relative to tomorrow
    # so e.g. today's day means today rather than a week ago
    Chronic.parse(dateref, now: today + 1.day, context: :past).to_date
  end
end
