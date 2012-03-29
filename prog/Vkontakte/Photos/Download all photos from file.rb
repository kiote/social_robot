#Находим альбом
paths = Album.get_from_file

paths.each do |path|
  album = Album.parse(path)
  #Если альбом существует
  if album
       #Выводим сообщение
       "Скачиваю #{album.name}...".print

       #Скачиваем фотографии
       album.photos.download
  else
      #Выводим сообщение об ошибке
       "Альбом не найден".print
  end
end