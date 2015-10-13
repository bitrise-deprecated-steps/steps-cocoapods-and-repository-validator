require 'find'
require 'pathname'

# -----------------------
# --- functions
# -----------------------

def xamarin_ios_project(project_file_path)
  query = 'Xamarin.iOS'
  unified_ios_api = File.readlines(project_file_path).grep(/#{query}/).size > 0

  query = 'monotouch'
  ios_api = File.readlines(project_file_path).grep(/#{query}/).size > 0

  (unified_ios_api || ios_api)
end

# -----------------------
# --- main
# -----------------------

project_root_dir = Dir.pwd
solution_file_paths = Find.find(project_root_dir).select { |p| /.*\.sln$/ =~ p }
puts "solution_file_paths: #{solution_file_paths}"

ios_project_file_paths = []
(solution_file_paths).each do |solution_file_path|
  pn = Pathname.new(solution_file_path)
  solution_base_dir_path, solution_file_name = pn.split

  query = '([^"]*.csproj)'
  matches = File.readlines("#{solution_file_path}").select { |n| n[/#{query}/i] }
  (matches).each do |match|
    splits = match.split(', ')
    project_file_name = splits[1].gsub(/\\/, '/').delete! '""'
    project_file_path = File.join(solution_base_dir_path, project_file_name)

    puts
    puts "raw_path: #{project_file_path}"
    puts

    if xamarin_ios_project(project_file_path)
      ios_project_file_paths.push(project_file_path)
    end
  end
end

puts
puts "xamarin ios projects: #{ios_project_file_paths}"
puts

exit_code = ios_project_file_paths.count > 0

puts
puts "exit_code: #{exit_code}"
puts

exit (ios_project_file_paths.count > 0 ? 0 : 1)
