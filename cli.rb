require 'mechanize'
require 'highline/import'
require 'terminal-table'

ROOT_URL = "http://pivotaltracker.com/"
DATE_FORMAT = "%m/%d/%Y"

agent = Mechanize.new
login_page = agent.get ROOT_URL + 'signin'

# ask for login credentials
username = ask("Username: ")
password = ask("Password: ") { |q| q.echo = false }

form = login_page.forms[0]
form["credentials[username]"] = username
form["credentials[password]"] = password
form.submit

def get_current_period
  today = Date.today
  day = today.day
  month = today.month
  year = today.year

  if day > 15
    first_day, last_day = 16, -1
  else
    first_day, last_day = 1, 15
  end

  [ Date.civil(year, month, first_day).strftime(DATE_FORMAT),
    Date.civil(year, month, last_day).strftime(DATE_FORMAT) ]
end

# time shifts page
time_shifts_page = agent.get ROOT_URL + 'time_shifts'
user_id = time_shifts_page.parser.css('#shift_person_id option[selected="selected"]').attr('value').text() 

default_start_date, default_end_date = get_current_period

start_date = ask("Start Date (MM/DD/YYYY): ") { |q| q.default = default_start_date }
end_date = ask("End Date (MM/DD/YYYY): ") { |q| q.default = default_end_date }

url_with_date_range = URI::escape(ROOT_URL + "time_shifts?date_period[start]=#{start_date}&date_period[finish]=#{end_date}&project=-1&person=#{user_id}&location=none&grouped_by=&commit=Submit")
time_shifts_page = agent.get url_with_date_range
time_shift_rows = time_shifts_page.parser.css('#shift_table tr')

table = Terminal::Table.new do |t|
  prev_entry = ""
  index = 0
  noOfRows = time_shift_rows.length - 2 # ignore table header and footer

  time_shift_rows[1..-2].each do |row|
    day     = row.css('td.date')[0].text().strip()
    date    = row.css('td.date')[1].text().strip()
    project = row.css('td.project').text().strip()
    hours   = row.css('td.hours').text().strip()

    if prev_entry != day and index.between?(1, noOfRows - 1)
      t.add_separator
    end
    t.add_row [day, date, project, hours]

    index += 1
    prev_entry = day
  end
end

puts table

#create_new_shifts_page = agent.get ROOT_URL + 'time_shifts/new'
