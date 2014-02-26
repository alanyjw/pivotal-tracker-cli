require 'mechanize'
require 'highline/import'
require 'terminal-table'

ROOT_URL = "http://pivotaltracker.com/"
DATE_FORMAT = "%m/%d/%Y"
LOCATION_ID = 23    # default location is Singapore

class TimeShift
  def initialize username, password
    @agent = Mechanize.new
    login_for username, password
  end

  def projects
    current_page = @agent.page
    project_links = current_page.links.select { |link| link.href.match(/\/projects\/[0-9]+$/) }
    project_links.map { |link| { id: link.href.match(/[0-9]+/)[0], name: link.text } }
  end

  def create_time_shift hours, description, project_id, location_id, date
    create_new_shifts_page = @agent.get ROOT_URL + 'time_shifts/new'

    form = create_new_shifts_page.forms[1]
    form["shift[hours]"] = hours
    form["shift[description]"] = description
    form["shift[project_id]"] = project_id
    form["shift[location_id]"] = location_id
    form["shift[date]"] = date
    form.submit
  end

  def print_time_shifts_for start_date, end_date
    time_shifts_page = @agent.get ROOT_URL + 'time_shifts'
    user_id = time_shifts_page.parser.css('#shift_person_id option[selected="selected"]').attr('value').text()

    url_with_date_range = URI::escape(ROOT_URL + "time_shifts?date_period[start]=#{start_date}&date_period[finish]=#{end_date}&project=-1&person=#{user_id}&location=none&grouped_by=&commit=Submit")
    time_shifts_page = @agent.get url_with_date_range
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
  end

  private
  def login_for username, password
    login_page = @agent.get ROOT_URL + 'signin'

    form = login_page.forms[0]
    form["credentials[username]"] = username
    form["credentials[password]"] = password
    form.submit
  end
end

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

username = ask("Username: ")
password = ask("Password: ") { |q| q.echo = false }

time_shift = TimeShift.new username, password

loop do
  choose do |menu|
    menu.header = "Options"

    menu.choice("Create a new time shift") do
      hours = ask("Hours: ") { |q| q.default = '8' }
      description = ask("Description: ") { |q| q.default = "" }
      date = ask("Date: ") { |q| q.default = Date.today.strftime(DATE_FORMAT) }

      projects_with_ids_and_names = time_shift.projects
      projects_with_names = projects_with_ids_and_names.map { |p| p[:name] }

      project_name = ""

      choose do |project_menu|
        project_menu.prompt = "Project: "
        project_menu.choices(*projects_with_names) { |command| project_name = command }
      end

      project_id = projects_with_ids_and_names.select { |p| p[:name] == project_name } .first[:id]

      time_shift.create_time_shift hours, description, project_id, LOCATION_ID, date
    end

    menu.choice("List time shifts for a date range") do
      default_start_date, default_end_date = get_current_period

      start_date = ask("Start Date (MM/DD/YYYY): ") { |q| q.default = default_start_date }
      end_date = ask("End Date (MM/DD/YYYY): ") { |q| q.default = default_end_date }

      time_shift.print_time_shifts_for start_date, end_date
    end

    menu.choice("Quit") { exit }
  end
end

