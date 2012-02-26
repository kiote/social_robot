#Находим людей
peoples = ask_peoples

#Для каждого человека
peoples.each_with_index do |user,i| 

    #Игнорировать ошибки
    safe do
         
         #Получить информацию о человеке
         skype = user.info["Skype"]

         #Продолжать если не указан Skype
         next if skype.nil?

         #Вывести skype
         "#{skype} => #{user.pretty_string}".print if(skype.length>=10)
    
         #Update progress bar
         total(i,peoples.length)
    end
end

