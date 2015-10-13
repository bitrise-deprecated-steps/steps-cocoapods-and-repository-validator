require 'find'
require 'pathname'

# -----------------------
# --- functions
# -----------------------

def xamarin_ios_project(project_file_path)
  query = '<Reference Include="Xamarin.iOS" />'
  unified_ios_api = File.readlines(project_file_path).grep(/#{query}/).size > 0

  query = '<Reference Include="monotouch" />'
  ios_api = File.readlines(project_file_path).grep(/#{query}/).size > 0

  (unified_ios_api || ios_api)
end

# -----------------------
# --- main
# -----------------------

ios_project_file_paths = []
Dir["**/*.sln"].each do |solution_file_path|
  puts
  puts "-> solution_file_path: #{solution_file_path}"
  puts

  pn = Pathname.new(solution_file_path)
  solution_base_dir_path, solution_file_name = pn.split

  query = '([^"]*.csproj)'
  matches = File.readlines("#{solution_file_path}").select { |n| n[/#{query}/i] }
  (matches).each do |match|
    splits = match.split(', ')
    project_file_name = splits[1].gsub(/\\/, '/').delete! '""'
    project_file_path = File.join(solution_base_dir_path, project_file_name)

    puts "  -> project_file_path: #{project_file_path}"

    is_xamarin_ios = xamarin_ios_project(project_file_path)

    puts "  -> is_xamarin_ios: #{is_xamarin_ios}"
    puts

    if is_xamarin_ios
      ios_project_file_paths.push(project_file_path)
    end

  end
end

puts
puts "xamarin ios projects: #{ios_project_file_paths}"
puts

exit (ios_project_file_paths.count > 0 ? 0 : 1)
