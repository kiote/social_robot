﻿class Settings
	@@doc = nil
	@@file_path = "../../settings/settings.xml"
	
	#Load document once
	def self.load_if_nil
		File.open(@@file_path) do |f|
			@@doc = Nokogiri::XML(f)
		end unless @@doc
	end
	
	#Load option value return nil if not present
	def self.[](key)
		load_if_nil
		res = @@doc.xpath("//#{key}")
		return nil if res.length == 0
		return res[0].text
	end
	
	
	#Save document
	def self.save
		File.open(@@file_path, 'w') {|f| f.write(@@doc.to_xml) } if @@doc
	end
	
	#Set value, if nil cleared
	def self.[]=(key,value)
		load_if_nil
		res = @@doc.xpath("//#{key}")[0]
		if value.nil?
			res.remove if res
			return 
		else
			if res
				res.content = value
				return
			end
			new_setting = Nokogiri::XML::Node.new key, @@doc
			new_setting.content = value
			@@doc.xpath("//settings")[0].add_child(new_setting)	
		end
	end
	
end


class SettingsWindow
	def self.show
		window = Qt::Dialog.new
		layout = Qt::GridLayout.new  

		use_anonymizer_label = Qt::Label.new
		use_anonymizer_label.text = "Использовать анонимайзер"
		layout.addWidget(use_anonymizer_label,0,0)
		use_anonymizer_ceckbox = Qt::CheckBox.new
		use_anonymizer_ceckbox.checked  = Settings["use_anonymizer"] == "true"
		layout.addWidget(use_anonymizer_ceckbox,0,1)


    user_fetch_interval_label = Qt::Label.new
		user_fetch_interval_label.text = "Интервал между загрузкой страницы пользователя"
		layout.addWidget(user_fetch_interval_label,1,0)
		user_fetch_interval_ceckbox = Qt::DoubleSpinBox.new
		user_fetch_interval_ceckbox.value  = Settings["user_fetch_interval"].to_f
		layout.addWidget(user_fetch_interval_ceckbox,1,1)


    photo_mark_interval_label = Qt::Label.new
		photo_mark_interval_label.text = "Интервал между отмечанием на фотографии"
		layout.addWidget(photo_mark_interval_label,2,0)
		photo_mark_interval_ceckbox = Qt::DoubleSpinBox.new
		photo_mark_interval_ceckbox.value  = Settings["photo_mark_interval"].to_f
		layout.addWidget(photo_mark_interval_ceckbox,2,1)


    like_interval_label = Qt::Label.new
		like_interval_label.text = "Интервал между лайком"
		layout.addWidget(like_interval_label,3,0)
		like_interval_ceckbox = Qt::DoubleSpinBox.new
		like_interval_ceckbox.value  = Settings["like_interval"].to_f
		layout.addWidget(like_interval_ceckbox,3,1)
		
		exit_button = Qt::PushButton.new("Ок",window)
		layout.addWidget(exit_button,4,1,Qt::AlignRight)
		window.connect(exit_button,SIGNAL('clicked()'),window,SLOT('accept()'))	
		
		
		layout.setContentsMargins(50,50,50,50)
		layout.HorizontalSpacing = 75
		layout.VerticalSpacing = 30
		window.windowTitle = "Настройки"
		window.setLayout(layout)
		if(window.exec!=0)
			Settings["use_anonymizer"] = use_anonymizer_ceckbox.checked.to_s
      Settings["user_fetch_interval"] = user_fetch_interval_ceckbox.value.to_s
      Settings["photo_mark_interval"] = photo_mark_interval_ceckbox.value.to_s
      Settings["like_interval"] = like_interval_ceckbox.value.to_s
			Settings.save		
		end
	end

		
end