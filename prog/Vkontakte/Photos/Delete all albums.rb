#Сначала спросить уверен ли пользовтель.
res = ask("Все альбомы будут удалены. Вы уверены?" => "check")

#Если пользователь ответил да - удалить альбомы
me.albums.remove if res[0]