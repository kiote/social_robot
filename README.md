﻿Что это такое?
------------------
Программа, для автоматизации рутинных действий в социальных сетях. Она включает в себя язык ruby, и библиотеки для работы с каждой. На данный момент доступна версия для вконтакте.


Как установить?
---------------------
Воспользоваться установщиком по адресу .


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

User.login(“Логин”,”Пароль”).name.print

Подружить двух людей:

	user1 = User.login("Логин 1","Пароль 1")
	user2 = User.login("Логин 2","Пароль 2")

	user1.invite(user2)
	user2.invite(user1)