require 'mechanize'
require 'highline/import'
require 'terminal-table'

ROOT_URL = "http://pivotaltracker.com/"

agent = Mechanize.new
login_page = agent.get ROOT_URL + 'signin'

# ask for login credentials
username = ask("Username: ")
password = ask("Password: ") { |q| q.echo = false }

form = login_page.forms[0]
form["credentials[username]"] = username
form["credentials[password]"] = password
form.submit

# time shifts page
time_shifts_page = agent.get ROOT_URL + 'time_shifts'
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
