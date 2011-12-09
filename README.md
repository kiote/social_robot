﻿Social Robot
============
Программа, для автоматизации рутинных действий в социальных сетях. Она включает в себя язык ruby, и библиотеки для работы с каждой. На данный момент доступна версия для вконтакте. Программа позволяет запускать программы написанные на ruby. Существует также множество готовых скриптов, которые не требуют ни знаний в программировании, ни специальной настройки.


Как установить?
---------------------
Воспользоваться установщиком по адресу https://github.com/downloads/kdkdkd/social_robot/socialrobot.exe


Что она умеет?
-------------------

### Основы

Скачать список друзей:
	
	me.friends.print

Объект me возвращает текущего пользователя. Функция print выводит сообщение в лог. В Библиотеке присутствует много синтаксического сахара, поэтому так написать тоже можно.
Вывести друзей моих друзей:

	me.friends.friends.print

Возможно, также зайти под другими пользователями.
Вывести имя пользователя:

	User.login("Логин","Пароль").name.print

Подружить двух людей:

	user1 = User.login("Логин 1","Пароль 1")
	user2 = User.login("Логин 2","Пароль 2")

	user1.invite(user2)
	user2.invite(user1)
	
	
Вывести информацию о человеке, который находиться на данной странице:
	
	User.parse("http://vkontakte.ru/id234").info.print
	
Чтобы не вводить значение в теле программы, можно спросить о значении у пользователя. Вывести информацию о человеке, который находиться странице:

	User.parse(ask_string("Адрес страницы")).info.print
	
	
### Скачка информации

Скачать мою музыку:
	
	me.music.download

Скачать всю музыку друзей:
	
	me.friends.music.download
	
Скачать фото Дурова:
	
	User.parse("http://vkontakte.ru/id1").albums.photos.download
	
Найти и скачать песню:

	Music.one(ask_string("Название песни")).download
	

### Спам

Разослать сообщения друзьям:

	me.friends.mail("Спам")

Разослать сообщения людям по результатам поиска:

	User.all("Интересы" => "anime", "Страна" => "Украина", "Город" => "Киев").mail("Спам")
	
Написать сообщение у себя на стене

	me.post("Сообщение")
	
Написать сообщение у на стене у друзей

	me.friends.post("Сообщение")


	
### Закачка информации	
	
Закачать всю музыку, которую пользователь выберет через диалог:

	Music.upload(ask_files)
	
Создать альбом и закачать туда фото:

	album = Album.create("Лето 2011")
	album.upload(ask_files)
	

Отметить всех друзей на фото. Так как вконтакте не позволяет отмечать на фотографии больше 35 людей, то мы создадим альбом и будем туда загружать одну и ту же фотографию для каждой пачки людей. Отметив их на фото с постером встречи, можно таким образом пригласить их:
	
	#Групируем друзей по 35
	grouped_friends = Array.new([])
	me.friends.each_with_index{|friend,index| grouped_friends[index/35].push(friend) }
	
	#Создаем альбом
	album = Album.create("Встреча в пятницу")
	
	#Выбираем какое фото будем заливать
	photo_location = ask_file
	
	#Для каждой группы
	grouped_friends.each do |friends_group|
		
		#Загружем фото
		photo = Album.upload(photo_location)
		
		#Отмечаем всех людей на фото
		photo.mark(friends_group)
	end
	
	


### Как приглашть друзей?

Приглашаем друзей в группу:

	#Находим нужную группу
	group = Groups.parse("http://vkontakte.ru/g238746")

	#Рассылаем приглашения
	group.invite(me.friends)
	

Пишем стандартный инвайтер: приглашаем к себе в друзья фанатов аниме:

	#Найти фанов аниме:
	anime_fans = User.all("Интересы" => "anime", "Страна" => "Украина", "Город" => "Киев")
	
	#Пригласить их в друзья
	me.invite(anime_fans,"Давай дружить!!!")

	
### Сбор информации

Найти людей по интересам и собрать их мобильные телефоны:
	
	#Список всех пользователей интересующихся программированием
	programmers = User.all("Интересы" => "Программирование", "Страна" => "Украина", "Город" => "Киев")
	
	#Для каждого програмиста
	programmers.each do |programmer| 
	
		#Вывести его телефон
		programmer.info["Моб. телефон"].print
	end

Теперь можно разослать смс каждому из них.


### Безопасность

Если Вы находитесь на работе - используйте анонимайзер. Для этого в меню Файл -> Настройки выберите соответствующий  пункт. Там же можно выбрать список прокси серверов, задать время, которое система должна ждать между опасными запросами.

Надоело самостоятельно заполнять капчи - воспользуйтесь одним из сервисов по разгадыванию капч. Этот пункт можно тоже изменить в настройках.

Программа не крадет ваши пароли, логины сессии. Аутентификационные данные не хранятся в чистом виде. Только сессия, она хранится в файле session/session.txt.