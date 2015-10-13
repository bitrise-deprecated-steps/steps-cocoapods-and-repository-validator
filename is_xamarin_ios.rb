require 'find'
require 'pathname'

# -----------------------
# --- functions
# -----------------------

def xamarin_ios_project(project_file_path)
  File.readlines(project_file_path).grep(/Include="(Xamarin.iOS)|(monotouch)"/).size > 0
end

# -----------------------
# --- main
# -----------------------

ios_project_file_paths = []
Dir["**/*.sln"].each do |solution_file_path|
  # puts
  # puts "-> solution_file_path: #{solution_file_path}"
  # puts

  pn = Pathname.new(solution_file_path)
  solution_base_dir_path, solution_file_name = pn.split

  query = 'Project\\(\"[^\"]*\"\\)\\s*=\\s*\"[^\"]*\",\\s*\"([^\"]*.csproj)\"'
  matches = File.readlines("#{solution_file_path}").select { |n| n[/#{query}/i] }
  (matches).each do |match|
    splits = match.split(', ')
    if splits.count == 3
      project_file_name = splits[1].gsub(/\\/, '/').delete! '""'
      project_file_path = File.join(solution_base_dir_path, project_file_name)

      # puts "  -> project_file_path: #{project_file_path}"

      is_xamarin_ios = xamarin_ios_project(project_file_path)

      # puts "  -> is_xamarin_ios: #{is_xamarin_ios}"
      # puts

      if is_xamarin_ios
        exit 0
      end
    else
      puts "  (error) unhandled solution content line: #{match}"
    end
  end
end

exit 1
