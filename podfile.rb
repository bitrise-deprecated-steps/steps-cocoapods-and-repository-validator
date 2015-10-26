class Podfile
	def method_missing symbol, *args
	end

	def self.from_file(path)
	  podfile = Podfile.new do
	  	@full_path = File.expand_path(path)
	  	@base_dir = File.dirname(@full_path)
	  	eval(File.open(@full_path).read, nil, path)
	  end
	end

	def initialize(&block)
	  @dependencies = []
	  instance_eval(&block)
	end

	def target(target_name, *args, &block)
		target_dict = {
			target: target_name,
			project: nil,
			workspace: nil,
			targets: []
		}

		parent_target = @current_target
		@current_target = target_dict

		block.call(self) if block

		if parent_target
			parent_target[:targets] << @current_target
		else
			(@targets ||= []) << @current_target
		end
		@current_target = parent_target
	end

	def xcodeproj(project, *args)
		if @current_target
			@current_target.project = project
		else
			@base_project = project
		end
	end

	def workspace(workspace, *args)
		if @current_target
			@current_target.workspace = workspace
		else
			@base_workspace = workspace
		end
	end

	# Helper

	def fix_targets(dict, parent)
		# If no explicit project is specified, it will use the Xcode project of the parent target.
		if parent != nil
			dict[:project] = parent[:project] unless dict[:project]
		end

		if dict[:project] == nil
			# If none of the target definitions specify an explicit project and there is only one project in the same directory
			# as the Podfile then that project will be used.
			projects = Dir[File.join(@base_dir, "*.xcodeproj")]

			if projects.count == 0
				dict[:error] = "No project found for Podfile at path: #{@base_dir}"
			end

			if projects.count > 1
				dict[:error] = "Multiple projects found for Podfile at path: #{@base_dir}. Check this reference for help: https://guides.cocoapods.org/syntax/podfile.html#xcodeproj"
			end

			dict[:project] = File.basename(projects.first, ".*")
		end

		# Check if the file exists
		project_path = File.join(@base_dir, "#{dict[:project]}.xcodeproj")
		unless File.exists?(project_path)
			dict[:error] = "No project found at path: #{project_path}"
		end

		# If no explicit Xcode workspace is specified and only one project exists in the same directory as the Podfile,
		# then the name of that project is used as the workspace’s name.
		if dict[:workspace] == nil
			if dict[:project] != nil
				dict[:workspace] = File.basename(dict[:project], '.*')
			end
		end

		dict[:targets].each do |t|
			fix_targets(t, dict)
		end

		dict
	end

	def list_targets
		base_target = {
			target: "",
			project: @base_project,
			workspace: @base_workspace,
			targets: @targets || []
		}

		[fix_targets(base_target, nil)]
	end

	def get_workspaces(dict)
		@workspaces ||= {}

		if dict[:error] == nil
			project_path = File.expand_path(File.join(@base_dir, "#{dict[:project]}.xcodeproj"))
			dir = File.dirname(project_path)
			workspace_path = File.join(dir, "#{dict[:workspace]}.xcworkspace")

			@workspaces[workspace_path] = project_path
		else
			puts "\e[31m#{dict[:error]}\e[0m"
		end

		dict[:targets].each do |target|
			get_workspaces(target)
		end

		@workspaces
	end
end