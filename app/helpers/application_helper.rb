module ApplicationHelper

    def post_date(date)
      # formatting date: Aug, 31 2007 - 9:55PM
      # date.strftime("posted on %b, %m %Y - %H:%M")
      date.in_time_zone.strftime("%d/%m/%Y")
    end

    def post_datetime(date)
      l(date, format: :default)
    end

end
