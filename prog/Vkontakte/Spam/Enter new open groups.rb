last = ask_string("Создайте группу и введите ее номер.\nЭто нужно чтобы определить какой номер последний").to_i


while true
     
     #Не вылетаем на исключениях
     
     safe{
           #Существует ли такая группа?
           group = Group.id(last)



           #Игнорируем ошибки
           safe do

                  #Если группа открыта
                  if group.open
          
                    #Войти
                    group.enter
          
                  end
          end
     
          #Перейти к следующей
          last+=1
    }

end 
