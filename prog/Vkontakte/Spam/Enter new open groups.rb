last = ask_string("Создайте группу и введите ее номер.\nЭто нужно чтобы определить какой номер последний").to_i


while true
     
    #Существует ли такая группа?
     group = Group.id(last)

     #Если группа открыта
     if group.open
          
          #Войти
          group.enter
          
     end
     
     #Перейти к следующей
     last+=1

end 
