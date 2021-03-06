require 'mechanize'

class Updater
	def last_version
		return @last_version if @last_version
		@last_version = Mechanize.new.get("https://raw.github.com/kiote/social_robot/master/version.txt").body
    
		@last_version
	end
	def current_version
		IO.read("../version.txt")
	end
	def update
		return if current_version == last_version
		begin
			Mechanize.new.get("https://github.com/downloads/kdkdkd/social_robot/version.txt")
		rescue
		end
		new_dir = "../../#{last_version}"
		#Clean old
		FileUtils.rm_rf new_dir if File.exists?(new_dir) && File.directory?(new_dir)
		Dir::mkdir(new_dir)
		current_zip = File.join(new_dir,"current.zip")
		#download
		Mechanize.new.get("https://github.com/kiote/social_robot/zipball/master").save(current_zip)
		rf = File.expand_path("../../")
		#extract
		 Zip::ZipFile.open(File.expand_path(current_zip)) { |zip_file|
			zip_file.each{|f|
					f_path = File.join(new_dir, f.name)
					f_path.gsub!(/[\\\/]kiote[^\\\/]*/,"")
					puts f_path
					FileUtils.mkdir_p(File.dirname(f_path))
					zip_file.extract(f, f_path)
				}
			}
			
		#delete archive
		File.delete(current_zip)
		#Update versionstart
		File.open("../../versionstart.txt","w") do |versionstart|
			versionstart<<last_version
		end
		last_version
	end
end