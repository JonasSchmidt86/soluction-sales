module ApplicationHelper

    def post_date(date)
      # formatting date: Aug, 31 2007 - 9:55PM
      # date.strftime("posted on %b, %m %Y - %H:%M")
      date.strftime("%d/%m/%Y")
    end

    def post_datetime(date)
      # formatting date: Aug, 31 2007 - 9:55PM
      date.strftime("%d/%m/%Y - %H:%M:%SS")
    end
   
end
