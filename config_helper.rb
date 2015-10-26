require "json"

class ConfigHelper
	def initialize
		@file_path = File.expand_path("~/.bitrise_config")
	end

	def save(project_type, branch, project_info)
		begin
			data = JSON.parse(File.read(@file_path))
		rescue
			data = {}
		end

		data[project_type] ||= {}
		data[project_type][branch] ||= { "projects" => [] }

		data[project_type][branch]["projects"] << project_info

		File.open(@file_path, "w") { |f| f.write(data.to_json) }
	end
end