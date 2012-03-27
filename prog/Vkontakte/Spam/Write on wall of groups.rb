#Метод отправки
send_method = ["Написать на стене или в комментариях", "Написать на стене", "Написать в комментариях"]

#Спросить, какое сообщение отправлять
result_ask = ask_media("Сообщение.\n\n#{aviable_text_features_groups}" => "text", "Отправлять на стену или в комментарии"=>{"Type" => "combo","Values" =>  send_method})
message = result_ask[0][0]
send_method_index = send_method.index(result_ask[0][1])
media = parse_media(result_ask[1],me,"wall") unless send_method_index == 2

#Наодим группы
groups = ask_groups


#Для каждой
groups.each_with_index do |group,index|
   
   #Копируем сообщение
   message_actual = sub(message)
    
   #Пишем на стене у человека
   post = nil 
   if(send_method_index < 2)
   	post = safe{group.post(message_actual,media[0],media[1],media[2])}
   end
   #Или в комментариях
   if((send_method_index == 2 || send_method_index == 0 && !post) && me.connect.able_to_post_on_wall)
	safe{w = group.wall(1)[0]; w.comment(message_actual) if w}
   end
   
   #Обновляем прогресс бар
   total(index,"-")
end