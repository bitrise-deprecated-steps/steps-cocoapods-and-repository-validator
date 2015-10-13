# Check for project files
projects = Dir.glob("**/*.xcodeproj", File::FNM_CASEFOLD)
workspaces = Dir.glob("**/*.xcworkspace", File::FNM_CASEFOLD)

exit 0 if (projects.count + workspaces.count) == 0

puts "\e[32miOS project detected\e[0m"

# Check for Podfiles
puts "Checking for Podfile"
podfiles = Dir.glob("**/Podfile", File::FNM_CASEFOLD)

podfiles.each do |podfile|
	next if podfile.include? ".git/"	# Don't check Podfile inside git directories

	

	# Update cocoapods if needed
	if ENV['is_update_cocoapods'] != "false"
		`bash "#{ENV['THIS_SCRIPTDIR']}/_steps-cocoapods-update/step.sh"`
		exit 1 if $?.statuscode != 0
	else
		puts "Skipping CocoaPods version update"
	end

	# Run `pod install`
	`bash "#{ENV['THIS_SCRIPTDIR']}/_steps-cocoapods-install/run_pod_install.sh"`
	exit 1 if $?.statuscode != 0
end

if podfiles.empty?
	puts "No Podfile found"
end