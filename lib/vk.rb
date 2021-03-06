﻿require 'mechanize'
require 'nokogiri'
require 'json'
require 'net/http'
require 'uri'



module Vkontakte

  #make post on wall common for User and Group
  module PostMaker

    def post(msg, attach_photo = nil, attach_video = nil, attach_music = nil ,connector=nil)
      connect_old = @connect
      @connect = forсe_login(connector,@connect)
	  unless @connect.able_to_post_on_wall
		@connect = connect_old
		return  
	  
	  end

      if(@connect.last_user_post)
        diff = Time.new - @connect.last_user_post
        sleep(Vkontakte::post_interval - diff) if(diff<Vkontakte::post_interval)
      end

      progress "Posting #{@id}..."
      captcha_sid = nil
      captcha_key = nil
      @post_hash = nil
      @info = nil

      return nil unless post_hash

      return nil unless(able_to_post)
      sleep Vkontakte::post_interval
      while true
        hash = {"act" => "post","al" => "1", "facebook_export" => "", "friends_only" => "", "hash" => post_hash, "message" => msg, "note_title" => "", "official" => "" , "status_export" => "", "to_id" => id_to_post, "type" => "all" }
        attach_number = 1
        if(attach_photo)
          hash["attach#{attach_number}"] = attach_photo
          hash["attach#{attach_number}_type"] = "photo"
          attach_number += 1
        end

        if(attach_video)
          hash["attach#{attach_number}"] = attach_video
          hash["attach#{attach_number}_type"] = "video"
          attach_number += 1
        end

        if(attach_music)
          hash["attach#{attach_number}"] = attach_music
          hash["attach#{attach_number}_type"] = "audio"
        end

        unless(captcha_key.nil?)
          hash["captcha_sid"] = captcha_sid
          hash["captcha_key"] = captcha_key
        end
        res = @connect.post('/al_wall.php', hash)
        if(res.index("<!json>"))
          html_text = res.split("<!>").find{|x| x.index('"post_table"')}
          return_value = Post.parse_html(Nokogiri::HTML(html_text.gsub("<!-- ->->","")),self,post_hash,"user",@connect)
          break
        else
          a = res.split("<!>")
          captcha_sid = a[a.length-2]
          if(captcha_sid == "8")
			      @connect.able_to_post_on_wall = false
			      progress :able_to_post_on_wall,@connect
			      return_value = nil
            break
          end
          if(captcha_sid == "11")
            @connect.able_to_post_on_wall = false
            progress :phone_to_post,@connect
            return_value = nil
            break
          end
		      if captcha_sid.length != 12
            return_value = nil
            break
          end
          captcha_key = @connect.ask_captcha_internal(captcha_sid)
        end
      end
      @connect.last_user_post = Time.new
      @connect = connect_old
      progress :user_post,self,return_value if return_value

      return_value
    end


    def wall(size = 5)
      return false unless @connect.login
      progress "Reading wall #{@id}..."
      return wall_offset(size) if size == "all"
      res_all = []
      index = 0
      while true do
        res = wall_offset(index.to_s)
        index += res.length
        break if res.length == 0 || res_all.length>=size.to_i
        res_all += res
      end
      return res_all
    end

    def wall_offset(offset = 0)
      if offset=="all"
        res_all = []
        index = 0
        while true do
          res = wall_offset(index.to_s)
          index += res.length
          break if res.length == 0
          res_all += res
        end
        return res_all
      end



      #res_post = @connect.post("/wall#{id}",{"offset" => offset.to_s, "al" => "1","part"=>"1"})
      res_post = @connect.post("/al_wall.php",{"act" => "get_wall","offset" => offset.to_s, "al" => "1","type"=>"all","owner_id"=>id_to_post})
      html_text = res_post.split("<!>").find{|x| x.index('"post_table"')}
      return [] unless html_text
      html = Nokogiri::HTML(html_text.gsub("<!-- ->->",""))

      res = []
      html.xpath("//*[@class='post_table']").each do |table|
        res.push Post.parse_html(table,self,((able_to_comment_post)? post_hash : nil),self.class.name,@connect)
      end
      res
    end

  end

  @@utf_converter = UtfToWin.new

  @@proxy_list = []
  def proxy_list=(value)
    @@proxy_list=value
  end

  @@user_list = []
  def user_list=(value)
    @@user_list=value
  end

  def user_list
    @@user_list
  end


  @@use_proxy = nil
  def use_proxy=(value)
    @@use_proxy=value
  end

  @@countries = {"\u0420\u043E\u0441\u0441\u0438\u044F"=>1,"\u0423\u043A\u0440\u0430\u0438\u043D\u0430"=>2,"\u0411\u0435\u043B\u0430\u0440\u0443\u0441\u044C"=>3, "\u041A\u0430\u0437\u0430\u0445\u0441\u0442\u0430\u043D"=>4,"\u0410\u0437\u0435\u0440\u0431\u0430\u0439\u0434\u0436\u0430\u043D"=>5, "\u0410\u0432\u0441\u0442\u0440\u0430\u043B\u0438\u044F"=>19, "\u0410\u0432\u0441\u0442\u0440\u0438\u044F"=>20,  "\u0410\u043B\u0431\u0430\u043D\u0438\u044F"=>21, "\u0410\u043B\u0436\u0438\u0440"=>22, "\u0410\u043C\u0435\u0440\u0438\u043A\u0430\u043D\u0441\u043A\u043E\u0435 \u0421\u0430\u043C\u043E\u0430"=>23, "\u0410\u043D\u0433\u0438\u043B\u044C\u044F"=>24, "\u0410\u043D\u0433\u043E\u043B\u0430"=>25, "\u0410\u043D\u0434\u043E\u0440\u0440\u0430"=>26, "\u0410\u043D\u0442\u0438\u0433\u0443\u0430 \u0438 \u0411\u0430\u0440\u0431\u0443\u0434\u0430"=>27, "\u0410\u0440\u0433\u0435\u043D\u0442\u0438\u043D\u0430"=>28, "\u0410\u0440\u043C\u0435\u043D\u0438\u044F"=>6, "\u0410\u0440\u0443\u0431\u0430"=>29, "\u0410\u0444\u0433\u0430\u043D\u0438\u0441\u0442\u0430\u043D"=>30, "\u0411\u0430\u0433\u0430\u043C\u044B"=>31, "\u0411\u0430\u043D\u0433\u043B\u0430\u0434\u0435\u0448"=>32, "\u0411\u0430\u0440\u0431\u0430\u0434\u043E\u0441"=>33, "\u0411\u0430\u0445\u0440\u0435\u0439\u043D"=>34, "\u0411\u0435\u043B\u0438\u0437"=>35, "\u0411\u0435\u043B\u044C\u0433\u0438\u044F"=>36, "\u0411\u0435\u043D\u0438\u043D"=>37, "\u0411\u0435\u0440\u043C\u0443\u0434\u044B"=>38, "\u0411\u043E\u043B\u0433\u0430\u0440\u0438\u044F"=>39, "\u0411\u043E\u043B\u0438\u0432\u0438\u044F"=>40, "\u0411\u043E\u0441\u043D\u0438\u044F \u0438 \u0413\u0435\u0440\u0446\u0435\u0433\u043E\u0432\u0438\u043D\u0430"=>41, "\u0411\u043E\u0442\u0441\u0432\u0430\u043D\u0430"=>42, "\u0411\u0440\u0430\u0437\u0438\u043B\u0438\u044F"=>43, "\u0411\u0440\u0443\u043D\u0435\u0439-\u0414\u0430\u0440\u0443\u0441\u0441\u0430\u043B\u0430\u043C"=>44, "\u0411\u0443\u0440\u043A\u0438\u043D\u0430-\u0424\u0430\u0441\u043E"=>45, "\u0411\u0443\u0440\u0443\u043D\u0434\u0438"=>46, "\u0411\u0443\u0442\u0430\u043D"=>47, "\u0412\u0430\u043D\u0443\u0430\u0442\u0443"=>48, "\u0412\u0435\u043B\u0438\u043A\u043E\u0431\u0440\u0438\u0442\u0430\u043D\u0438\u044F"=>49, "\u0412\u0435\u043D\u0433\u0440\u0438\u044F"=>50, "\u0412\u0435\u043D\u0435\u0441\u0443\u044D\u043B\u0430"=>51, "\u0412\u0438\u0440\u0433\u0438\u043D\u0441\u043A\u0438\u0435 \u043E\u0441\u0442\u0440\u043E\u0432\u0430, \u0411\u0440\u0438\u0442\u0430\u043D\u0441\u043A\u0438\u0435"=>52, "\u0412\u0438\u0440\u0433\u0438\u043D\u0441\u043A\u0438\u0435 \u043E\u0441\u0442\u0440\u043E\u0432\u0430, \u0421\u0428\u0410"=>53, "\u0412\u043E\u0441\u0442\u043E\u0447\u043D\u044B\u0439 \u0422\u0438\u043C\u043E\u0440"=>54, "\u0412\u044C\u0435\u0442\u043D\u0430\u043C"=>55, "\u0413\u0430\u0431\u043E\u043D"=>56, "\u0413\u0430\u0438\u0442\u0438"=>57, "\u0413\u0430\u0439\u0430\u043D\u0430"=>58, "\u0413\u0430\u043C\u0431\u0438\u044F"=>59, "\u0413\u0430\u043D\u0430"=>60, "\u0413\u0432\u0430\u0434\u0435\u043B\u0443\u043F\u0430"=>61, "\u0413\u0432\u0430\u0442\u0435\u043C\u0430\u043B\u0430"=>62, "\u0413\u0432\u0438\u043D\u0435\u044F"=>63, "\u0413\u0432\u0438\u043D\u0435\u044F-\u0411\u0438\u0441\u0430\u0443"=>64, "\u0413\u0435\u0440\u043C\u0430\u043D\u0438\u044F"=>65, "\u0413\u0438\u0431\u0440\u0430\u043B\u0442\u0430\u0440"=>66, "\u0413\u043E\u043D\u0434\u0443\u0440\u0430\u0441"=>67, "\u0413\u043E\u043D\u043A\u043E\u043D\u0433"=>68, "\u0413\u0440\u0435\u043D\u0430\u0434\u0430"=>69, "\u0413\u0440\u0435\u043D\u043B\u0430\u043D\u0434\u0438\u044F"=>70, "\u0413\u0440\u0435\u0446\u0438\u044F"=>71, "\u0413\u0440\u0443\u0437\u0438\u044F"=>7, "\u0413\u0443\u0430\u043C"=>72, "\u0414\u0430\u043D\u0438\u044F"=>73, "\u0414\u0436\u0438\u0431\u0443\u0442\u0438"=>231, "\u0414\u043E\u043C\u0438\u043D\u0438\u043A\u0430"=>74, "\u0414\u043E\u043C\u0438\u043D\u0438\u043A\u0430\u043D\u0441\u043A\u0430\u044F \u0420\u0435\u0441\u043F\u0443\u0431\u043B\u0438\u043A\u0430"=>75, "\u0415\u0433\u0438\u043F\u0435\u0442"=>76, "\u0417\u0430\u043C\u0431\u0438\u044F"=>77, "\u0417\u0430\u043F\u0430\u0434\u043D\u0430\u044F \u0421\u0430\u0445\u0430\u0440\u0430"=>78, "\u0417\u0438\u043C\u0431\u0430\u0431\u0432\u0435"=>79, "\u0418\u0437\u0440\u0430\u0438\u043B\u044C"=>8, "\u0418\u043D\u0434\u0438\u044F"=>80, "\u0418\u043D\u0434\u043E\u043D\u0435\u0437\u0438\u044F"=>81, "\u0418\u043E\u0440\u0434\u0430\u043D\u0438\u044F"=>82, "\u0418\u0440\u0430\u043A"=>83, "\u0418\u0440\u0430\u043D"=>84, "\u0418\u0440\u043B\u0430\u043D\u0434\u0438\u044F"=>85, "\u0418\u0441\u043B\u0430\u043D\u0434\u0438\u044F"=>86, "\u0418\u0441\u043F\u0430\u043D\u0438\u044F"=>87, "\u0418\u0442\u0430\u043B\u0438\u044F"=>88, "\u0419\u0435\u043C\u0435\u043D"=>89, "\u041A\u0430\u0431\u043E-\u0412\u0435\u0440\u0434\u0435"=>90, "\u041A\u0430\u043C\u0431\u043E\u0434\u0436\u0430"=>91, "\u041A\u0430\u043C\u0435\u0440\u0443\u043D"=>92, "\u041A\u0430\u043D\u0430\u0434\u0430"=>10, "\u041A\u0430\u0442\u0430\u0440"=>93, "\u041A\u0435\u043D\u0438\u044F"=>94, "\u041A\u0438\u043F\u0440"=>95, "\u041A\u0438\u0440\u0438\u0431\u0430\u0442\u0438"=>96, "\u041A\u0438\u0442\u0430\u0439"=>97, "\u041A\u043E\u043B\u0443\u043C\u0431\u0438\u044F"=>98, "\u041A\u043E\u043C\u043E\u0440\u044B"=>99, "\u041A\u043E\u043D\u0433\u043E"=>100, "\u041A\u043E\u043D\u0433\u043E, \u0434\u0435\u043C\u043E\u043A\u0440\u0430\u0442\u0438\u0447\u0435\u0441\u043A\u0430\u044F \u0440\u0435\u0441\u043F\u0443\u0431\u043B\u0438\u043A\u0430"=>101, "\u041A\u043E\u0441\u0442\u0430-\u0420\u0438\u043A\u0430"=>102, "\u041A\u043E\u0442 \u0434`\u0418\u0432\u0443\u0430\u0440"=>103, "\u041A\u0443\u0431\u0430"=>104, "\u041A\u0443\u0432\u0435\u0439\u0442"=>105, "\u041A\u044B\u0440\u0433\u044B\u0437\u0441\u0442\u0430\u043D"=>11, "\u041B\u0430\u043E\u0441"=>106, "\u041B\u0430\u0442\u0432\u0438\u044F"=>12, "\u041B\u0435\u0441\u043E\u0442\u043E"=>107, "\u041B\u0438\u0431\u0435\u0440\u0438\u044F"=>108, "\u041B\u0438\u0432\u0430\u043D"=>109, "\u041B\u0438\u0432\u0438\u0439\u0441\u043A\u0430\u044F \u0410\u0440\u0430\u0431\u0441\u043A\u0430\u044F \u0414\u0436\u0430\u043C\u0430\u0445\u0438\u0440\u0438\u044F"=>110, "\u041B\u0438\u0442\u0432\u0430"=>13, "\u041B\u0438\u0445\u0442\u0435\u043D\u0448\u0442\u0435\u0439\u043D"=>111, "\u041B\u044E\u043A\u0441\u0435\u043C\u0431\u0443\u0440\u0433"=>112, "\u041C\u0430\u0432\u0440\u0438\u043A\u0438\u0439"=>113, "\u041C\u0430\u0432\u0440\u0438\u0442\u0430\u043D\u0438\u044F"=>114, "\u041C\u0430\u0434\u0430\u0433\u0430\u0441\u043A\u0430\u0440"=>115, "\u041C\u0430\u043A\u0430\u043E"=>116, "\u041C\u0430\u043A\u0435\u0434\u043E\u043D\u0438\u044F"=>117, "\u041C\u0430\u043B\u0430\u0432\u0438"=>118, "\u041C\u0430\u043B\u0430\u0439\u0437\u0438\u044F"=>119, "\u041C\u0430\u043B\u0438"=>120, "\u041C\u0430\u043B\u044C\u0434\u0438\u0432\u044B"=>121, "\u041C\u0430\u043B\u044C\u0442\u0430"=>122, "\u041C\u0430\u0440\u043E\u043A\u043A\u043E"=>123, "\u041C\u0430\u0440\u0442\u0438\u043D\u0438\u043A\u0430"=>124, "\u041C\u0430\u0440\u0448\u0430\u043B\u043B\u043E\u0432\u044B \u041E\u0441\u0442\u0440\u043E\u0432\u0430"=>125, "\u041C\u0435\u043A\u0441\u0438\u043A\u0430"=>126, "\u041C\u0438\u043A\u0440\u043E\u043D\u0435\u0437\u0438\u044F, \u0444\u0435\u0434\u0435\u0440\u0430\u0442\u0438\u0432\u043D\u044B\u0435 \u0448\u0442\u0430\u0442\u044B"=>127, "\u041C\u043E\u0437\u0430\u043C\u0431\u0438\u043A"=>128, "\u041C\u043E\u043B\u0434\u043E\u0432\u0430"=>15, "\u041C\u043E\u043D\u0430\u043A\u043E"=>129, "\u041C\u043E\u043D\u0433\u043E\u043B\u0438\u044F"=>130, "\u041C\u043E\u043D\u0442\u0441\u0435\u0440\u0440\u0430\u0442"=>131, "\u041C\u044C\u044F\u043D\u043C\u0430"=>132, "\u041D\u0430\u043C\u0438\u0431\u0438\u044F"=>133, "\u041D\u0430\u0443\u0440\u0443"=>134, "\u041D\u0435\u043F\u0430\u043B"=>135, "\u041D\u0438\u0433\u0435\u0440"=>136, "\u041D\u0438\u0433\u0435\u0440\u0438\u044F"=>137, "\u041D\u0438\u0434\u0435\u0440\u043B\u0430\u043D\u0434\u0441\u043A\u0438\u0435 \u0410\u043D\u0442\u0438\u043B\u044B"=>138, "\u041D\u0438\u0434\u0435\u0440\u043B\u0430\u043D\u0434\u044B"=>139, "\u041D\u0438\u043A\u0430\u0440\u0430\u0433\u0443\u0430"=>140, "\u041D\u0438\u0443\u044D"=>141, "\u041D\u043E\u0432\u0430\u044F \u0417\u0435\u043B\u0430\u043D\u0434\u0438\u044F"=>142, "\u041D\u043E\u0432\u0430\u044F \u041A\u0430\u043B\u0435\u0434\u043E\u043D\u0438\u044F"=>143, "\u041D\u043E\u0440\u0432\u0435\u0433\u0438\u044F"=>144, "\u041E\u0431\u044A\u0435\u0434\u0438\u043D\u0435\u043D\u043D\u044B\u0435 \u0410\u0440\u0430\u0431\u0441\u043A\u0438\u0435 \u042D\u043C\u0438\u0440\u0430\u0442\u044B"=>145, "\u041E\u043C\u0430\u043D"=>146, "\u041E\u0441\u0442\u0440\u043E\u0432 \u041C\u044D\u043D"=>147, "\u041E\u0441\u0442\u0440\u043E\u0432 \u041D\u043E\u0440\u0444\u043E\u043B\u043A"=>148, "\u041E\u0441\u0442\u0440\u043E\u0432\u0430 \u041A\u0430\u0439\u043C\u0430\u043D"=>149, "\u041E\u0441\u0442\u0440\u043E\u0432\u0430 \u041A\u0443\u043A\u0430"=>150, "\u041E\u0441\u0442\u0440\u043E\u0432\u0430 \u0422\u0435\u0440\u043A\u0441 \u0438 \u041A\u0430\u0439\u043A\u043E\u0441"=>151, "\u041F\u0430\u043A\u0438\u0441\u0442\u0430\u043D"=>152, "\u041F\u0430\u043B\u0430\u0443"=>153, "\u041F\u0430\u043B\u0435\u0441\u0442\u0438\u043D\u0441\u043A\u0430\u044F \u0430\u0432\u0442\u043E\u043D\u043E\u043C\u0438\u044F"=>154, "\u041F\u0430\u043D\u0430\u043C\u0430"=>155, "\u041F\u0430\u043F\u0443\u0430 - \u041D\u043E\u0432\u0430\u044F \u0413\u0432\u0438\u043D\u0435\u044F"=>156, "\u041F\u0430\u0440\u0430\u0433\u0432\u0430\u0439"=>157, "\u041F\u0435\u0440\u0443"=>158, "\u041F\u0438\u0442\u043A\u0435\u0440\u043D"=>159, "\u041F\u043E\u043B\u044C\u0448\u0430"=>160, "\u041F\u043E\u0440\u0442\u0443\u0433\u0430\u043B\u0438\u044F"=>161, "\u041F\u0443\u044D\u0440\u0442\u043E-\u0420\u0438\u043A\u043E"=>162, "\u0420\u0435\u044E\u043D\u044C\u043E\u043D"=>163, "\u0420\u0443\u0430\u043D\u0434\u0430"=>164, "\u0420\u0443\u043C\u044B\u043D\u0438\u044F"=>165, "\u0421\u0428\u0410"=>9, "\u0421\u0430\u043B\u044C\u0432\u0430\u0434\u043E\u0440"=>166, "\u0421\u0430\u043C\u043E\u0430"=>167, "\u0421\u0430\u043D-\u041C\u0430\u0440\u0438\u043D\u043E"=>168, "\u0421\u0430\u043D-\u0422\u043E\u043C\u0435 \u0438 \u041F\u0440\u0438\u043D\u0441\u0438\u043F\u0438"=>169, "\u0421\u0430\u0443\u0434\u043E\u0432\u0441\u043A\u0430\u044F \u0410\u0440\u0430\u0432\u0438\u044F"=>170, "\u0421\u0432\u0430\u0437\u0438\u043B\u0435\u043D\u0434"=>171, "\u0421\u0432\u044F\u0442\u0430\u044F \u0415\u043B\u0435\u043D\u0430"=>172, "\u0421\u0435\u0432\u0435\u0440\u043D\u0430\u044F \u041A\u043E\u0440\u0435\u044F"=>173, "\u0421\u0435\u0432\u0435\u0440\u043D\u044B\u0435 \u041C\u0430\u0440\u0438\u0430\u043D\u0441\u043A\u0438\u0435 \u043E\u0441\u0442\u0440\u043E\u0432\u0430"=>174, "\u0421\u0435\u0439\u0448\u0435\u043B\u044B"=>175, "\u0421\u0435\u043D\u0435\u0433\u0430\u043B"=>176, "\u0421\u0435\u043D\u0442-\u0412\u0438\u043D\u0441\u0435\u043D\u0442"=>177, "\u0421\u0435\u043D\u0442-\u041A\u0438\u0442\u0441 \u0438 \u041D\u0435\u0432\u0438\u0441"=>178, "\u0421\u0435\u043D\u0442-\u041B\u044E\u0441\u0438\u044F"=>179, "\u0421\u0435\u043D\u0442-\u041F\u044C\u0435\u0440 \u0438 \u041C\u0438\u043A\u0435\u043B\u043E\u043D"=>180, "\u0421\u0435\u0440\u0431\u0438\u044F"=>181, "\u0421\u0438\u043D\u0433\u0430\u043F\u0443\u0440"=>182, "\u0421\u0438\u0440\u0438\u0439\u0441\u043A\u0430\u044F \u0410\u0440\u0430\u0431\u0441\u043A\u0430\u044F \u0420\u0435\u0441\u043F\u0443\u0431\u043B\u0438\u043A\u0430"=>183, "\u0421\u043B\u043E\u0432\u0430\u043A\u0438\u044F"=>184, "\u0421\u043B\u043E\u0432\u0435\u043D\u0438\u044F"=>185, "\u0421\u043E\u043B\u043E\u043C\u043E\u043D\u043E\u0432\u044B \u041E\u0441\u0442\u0440\u043E\u0432\u0430"=>186, "\u0421\u043E\u043C\u0430\u043B\u0438"=>187, "\u0421\u0443\u0434\u0430\u043D"=>188, "\u0421\u0443\u0440\u0438\u043D\u0430\u043C"=>189, "\u0421\u044C\u0435\u0440\u0440\u0430-\u041B\u0435\u043E\u043D\u0435"=>190, "\u0422\u0430\u0434\u0436\u0438\u043A\u0438\u0441\u0442\u0430\u043D"=>16, "\u0422\u0430\u0438\u043B\u0430\u043D\u0434"=>191, "\u0422\u0430\u0439\u0432\u0430\u043D\u044C"=>192, "\u0422\u0430\u043D\u0437\u0430\u043D\u0438\u044F"=>193, "\u0422\u043E\u0433\u043E"=>194, "\u0422\u043E\u043A\u0435\u043B\u0430\u0443"=>195, "\u0422\u043E\u043D\u0433\u0430"=>196, "\u0422\u0440\u0438\u043D\u0438\u0434\u0430\u0434 \u0438 \u0422\u043E\u0431\u0430\u0433\u043E"=>197, "\u0422\u0443\u0432\u0430\u043B\u0443"=>198, "\u0422\u0443\u043D\u0438\u0441"=>199, "\u0422\u0443\u0440\u043A\u043C\u0435\u043D\u0438\u044F"=>17, "\u0422\u0443\u0440\u0446\u0438\u044F"=>200, "\u0423\u0433\u0430\u043D\u0434\u0430"=>201, "\u0423\u0437\u0431\u0435\u043A\u0438\u0441\u0442\u0430\u043D"=>18, "\u0423\u043E\u043B\u043B\u0438\u0441 \u0438 \u0424\u0443\u0442\u0443\u043D\u0430"=>202, "\u0423\u0440\u0443\u0433\u0432\u0430\u0439"=>203, "\u0424\u0430\u0440\u0435\u0440\u0441\u043A\u0438\u0435 \u043E\u0441\u0442\u0440\u043E\u0432\u0430"=>204, "\u0424\u0438\u0434\u0436\u0438"=>205, "\u0424\u0438\u043B\u0438\u043F\u043F\u0438\u043D\u044B"=>206, "\u0424\u0438\u043D\u043B\u044F\u043D\u0434\u0438\u044F"=>207, "\u0424\u043E\u043B\u043A\u043B\u0435\u043D\u0434\u0441\u043A\u0438\u0435 \u043E\u0441\u0442\u0440\u043E\u0432\u0430"=>208, "\u0424\u0440\u0430\u043D\u0446\u0438\u044F"=>209, "\u0424\u0440\u0430\u043D\u0446\u0443\u0437\u0441\u043A\u0430\u044F \u0413\u0432\u0438\u0430\u043D\u0430"=>210, "\u0424\u0440\u0430\u043D\u0446\u0443\u0437\u0441\u043A\u0430\u044F \u041F\u043E\u043B\u0438\u043D\u0435\u0437\u0438\u044F"=>211, "\u0425\u043E\u0440\u0432\u0430\u0442\u0438\u044F"=>212, "\u0426\u0435\u043D\u0442\u0440\u0430\u043B\u044C\u043D\u043E-\u0410\u0444\u0440\u0438\u043A\u0430\u043D\u0441\u043A\u0430\u044F \u0420\u0435\u0441\u043F\u0443\u0431\u043B\u0438\u043A\u0430"=>213, "\u0427\u0430\u0434"=>214, "\u0427\u0435\u0440\u043D\u043E\u0433\u043E\u0440\u0438\u044F"=>230, "\u0427\u0435\u0445\u0438\u044F"=>215, "\u0427\u0438\u043B\u0438"=>216, "\u0428\u0432\u0435\u0439\u0446\u0430\u0440\u0438\u044F"=>217, "\u0428\u0432\u0435\u0446\u0438\u044F"=>218, "\u0428\u043F\u0438\u0446\u0431\u0435\u0440\u0433\u0435\u043D \u0438 \u042F\u043D \u041C\u0430\u0439\u0435\u043D"=>219, "\u0428\u0440\u0438-\u041B\u0430\u043D\u043A\u0430"=>220, "\u042D\u043A\u0432\u0430\u0434\u043E\u0440"=>221, "\u042D\u043A\u0432\u0430\u0442\u043E\u0440\u0438\u0430\u043B\u044C\u043D\u0430\u044F \u0413\u0432\u0438\u043D\u0435\u044F"=>222, "\u042D\u0440\u0438\u0442\u0440\u0435\u044F"=>223, "\u042D\u0441\u0442\u043E\u043D\u0438\u044F"=>14, "\u042D\u0444\u0438\u043E\u043F\u0438\u044F"=>224, "\u042E\u0436\u043D\u0430\u044F \u041A\u043E\u0440\u0435\u044F"=>226, "\u042E\u0436\u043D\u043E-\u0410\u0444\u0440\u0438\u043A\u0430\u043D\u0441\u043A\u0430\u044F \u0420\u0435\u0441\u043F\u0443\u0431\u043B\u0438\u043A\u0430"=>227, "\u042F\u043C\u0430\u0439\u043A\u0430"=>228, "\u042F\u043F\u043E\u043D\u0438\u044F"=>229}
  def countries
    @@countries
  end

  #Skip errors
  def safe
    res = nil
    begin
      res = yield
    rescue Exception => e
      progress :exception,e
      res = nil
    end
    res
  end

  #Output message about what system has done
  #This function can be overloaded by client
  #If has one argument - it holds the brief action, what system is doing
  #If many - first is symbol which describes completed action, second more info. see logger_html
  def progress(*args, &block)
    @@progress_block = block if block
    @@progress_block.call(*args) if defined?(@@progress_block) && args.length>0
  end


  def failed(*args, &block)
    @@failed_block = block if block
    @@failed_block.call(*args) if defined?(@@failed_block) && args.length>0
  end


  def update_session(*args, &block)
    @@update_session = block if block
    @@update_session.call(*args) if defined?(@@update_session) && args.length>0
  end

  @@user_fetch_interval = 2.1
  def user_fetch_interval=(value)
    @@user_fetch_interval=value
  end

  @@user_login_interval = 4
  def user_login_interval=(value)
    @@user_login_interval=value
  end

  def user_login_interval
    @@user_login_interval
  end

  @@last_user_login = nil
  def last_user_login
    @@last_user_login
  end

  @@transform_captcha = false
  def transform_captcha=(value)
    @@transform_captcha=value
  end

  @@photo_mark_interval = 5
  def photo_mark_interval=(value)
    @@photo_mark_interval=value
  end

  @@like_interval = 1
  def like_interval=(value)
    @@like_interval=value
  end

  @@mail_interval = 3
  def mail_interval=(value)
    @@mail_interval=value
  end
  def mail_interval
    @@mail_interval
  end

  @@post_interval = 4
  def post_interval=(value)
    @@post_interval=value
  end

  def post_interval
    @@post_interval
  end

  @@invite_interval = 8
  def invite_interval=(value)
    @@invite_interval=value
  end

  #which page is to refer all reqests
  @@vkontakte_location_var = "http://vk.com"

  #change page which refers all requests
  def force_location(location = "http://vk.com")
    @@vkontakte_location_var = location
  end

  #get page which refers all requests
  def vkontakte_location
    @@vkontakte_location_var
  end


  #Ask user to resolve captcha
  def ask_captcha(*args, &block)
    @@ask_captcha_block = block if block
    @@ask_captcha_block.call args[0] if args.length>0 && @@ask_captcha_block
  end

  @@main_user = nil
  def main_user=(value)
    @@main_user=value
  end

  #Ask user to login
  def ask_login(*args, &block)
    if block
      @@ask_login_block = block
    else
      @@ask_login_block.call if @@ask_login_block
    end
  end

  #Try to login in any way
  def forсe_login(connector,self_connect=nil)
    connect = nil
    if connector
      connect = connector.connect
    elsif !self_connect.nil?
      connect = self_connect
    else
      ask_res = ask_login
      connect = ask_res.connect if ask_res
    end
    connect
  end


  @@application_directory = "."
  def application_directory=(value)
    @@application_directory = value
  end

  def application_directory
    @@application_directory
  end

  def loot_directory
    File.join(Vkontakte::application_directory,"loot")
  end

  def convert_exe
    File.join(Vkontakte::application_directory,"magick","convert.exe")
  end


  #Used to upload files with non latin file names
  def safe_file_name(filename)
    basename = File.basename(filename)
    all_ascii = true
    basename.each_byte do |c|
      if c>=128
        all_ascii = false
        break
      end
    end


    if(all_ascii)
      yield(filename)
    else
      new_file_name = File.dirname(filename) + '/' + (0...8).map{ ('a'..'z').to_a[rand(26)] }.join + File.extname(filename)
      FileUtils.cp(filename,new_file_name)
      yield(new_file_name)
      FileUtils.rm(new_file_name)
    end
  end

  class Connect
    attr_reader :uid
    attr_accessor :last_user_mark_photo, :last_user_like, :last_user_mail, :last_user_post, :last_user_invite, :able_to_send_message, :able_to_invite_to_group, :able_to_invite_friend, :invite_box, :able_to_post_on_wall, :able_to_like


    def cookie
      @cookie_login
    end



    def new_agent
      @agent = Mechanize.new { |agent|  agent.user_agent_alias = 'Mac Safari'	}
      @agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      @agent.agent.http.retry_change_requests = true
    end

    def initialize(login = nil, password = nil)
      @able_to_like = true
      @able_to_send_message = true
      @able_to_invite_to_group = true
      @able_to_invite_friend = true
	    @able_to_post_on_wall = true
      @invite_box = {}
      new_agent

      if(@@use_proxy && @@proxy_list.length>0)
        found_proxy = false
        proxy_list_small = @@proxy_list
        while(!found_proxy)
          current_proxy = proxy_list_small.sample
          if(current_proxy.nil?)
            new_agent
            break
          end
          progress :try_proxy,current_proxy[0]
          if current_proxy
            begin
              @agent.set_proxy(current_proxy[0], current_proxy[1].to_i, current_proxy[2], current_proxy[3])
              @agent.get(addr("/"))
              found_proxy = true
              progress :ok_proxy,current_proxy[0]
            rescue
              proxy_list_small.delete(current_proxy)
              progress :bad_proxy,current_proxy[0]
              new_agent
            end
          else
            new_agent
            break
          end
        end
      end

      @email = login
      @password = password
    end

    def email
      @email
    end


    #Check if connection is ok
    def check_login(login_text)
      begin
        @agent.redirect_ok = false
        resp = nil
        begin
          resp = @agent.get(addr("/feed"),[],nil,{'cookie' => @cookie_login})
          @agent.redirect_ok = true
        rescue
          @agent.redirect_ok = true
          return nil
        end
        location = resp.response['location']
        #Phone needed
        if(location.to_s.index('security_check'))
          last_numbers = login_text[/\d\d\d\d$/]
          return nil unless last_numbers
          to = location.scan(/to\=([^\&]+)/)[0][0]
          #Follow redirect
          begin
            resp = @agent.get(addr(location),[],nil,{'cookie' => @cookie_login})
          rescue
            return nil
          end
          res = resp.body
          #Get hash
          hash = res.scan(/hash\s*\:\s*\'?\"?([^\"\']+)\"?\'?/)[0][0]
          post("/login.php",{"act"=>"security_check","al"=>"1","al_page"=>"3","code"=>last_numbers,"hash"=>hash,"to"=>to})
          begin
            resp = @agent.get(addr("/feed"),[],nil,{'cookie' => @cookie_login})
          rescue
            return nil
          end
        end
        res = resp.body
        res.force_encoding("cp1251")
        res = res.encode("utf-8")

        id = User.get_id_by_feed(res)
        @uid = id
        return id
      rescue
        return false
      end
    end

    def ask_captcha_internal(captcha_sid)
      file_name = save(addr("/captcha.php?sid=#{captcha_sid}"),"captcha","#{captcha_sid}.jpg",true)
      if(@@transform_captcha)
        file_name_png = file_name.gsub(".jpg",".png")
        command = "\"#{Vkontakte::convert_exe}\" \"#{file_name}\" \"#{file_name_png}\""
        system(command)
      end
      captcha_key = ask_captcha(captcha_sid)

      begin
        File.delete file_name
        File.delete file_name_png if(@@transform_captcha)
      rescue
      end
      captcha_key
    end

    #Save some file to loot folder
    def save(url,folder,filename,with_mechanize = false)
      path = File.join(Vkontakte::loot_directory,folder)
      Dir::mkdir(path) unless File.exists?(path) && File.directory?(path)
      progress "Downloading " + url
      filename = filename.gsub(/[\\\/\:\"\*\?\<\>\|]+/,'').gsub("\s","_")
      ext = File.extname(filename)
      basename = filename.chomp(ext)
      basename = basename[0..99] + "..." if basename.length>100
      res = File.join(path,basename + ext)
      return res if File.exist?(res)
      if(with_mechanize)
        @agent.get(url,[],nil,{'cookie' => @cookie_login}).save(res)
      else
        uri = URI(url)
        Net::HTTP.start(uri.host) do |http|
          resp = http.get(uri.path)
          File.open(res, "wb") do |file|
            file.write(resp.body)
          end
        end
      end
      res
    end

    #Make GET request
    def get(href)
      begin
        res = @agent.get(addr(href),[],nil,{'cookie' => @cookie_login}).body
      rescue Exception => e
        e.message.print
        href.print
        return nil
      end
      res.force_encoding("cp1251")
      res = res.encode("utf-8")
      res
    end

    #Fetch user page
    def get_user(id)
      if(@last_user_fetch_date)
        diff = Time.new - @last_user_fetch_date
        sleep(@@user_fetch_interval - diff) if(diff<@@user_fetch_interval)
      end

      not_ok = true
      sleep_time = 100
      while not_ok do
        addr_of_user = (id =~ /^\d+$/)? ("/id" + id):("/" + id)
        res = get(addr_of_user)
        return nil if res.nil?
        if(res.index('"post_hash"') || res.index('"profile_deleted_text"') || res.index('"profile_blocked"'))
          not_ok = false
        else
          return nil unless res.index("<title>Помилка</title>") || res.index("<title>Ошибка</title>") || res.index("<title>Error</title>")
		  
		  return nil if(sleep_time>2000)
          sleep sleep_time

          sleep_time *= 2
        end
      end
      @last_user_fetch_date = Time.new
      if(res && res.index('"post_hash"'))
        res
      else
        nil
      end

    end

    #Fetch group page
    def get_group(id,type)
      if(@last_user_fetch_date)
        diff = Time.new - @last_user_fetch_date
        sleep(@@user_fetch_interval - diff) if(diff<@@user_fetch_interval)
      end
      if id =~ /^\d+$/
        if(type == "group")
          href = "/club#{id}"
        else
          href = "/public#{id}"
        end
      else
        href = "/#{id}"
      end

      res = get(href)
      if(type == "unknown" && User.get_id_by_feed(res) == "0")
        res = get("/club#{id}")
      end
      @last_user_fetch_date = Time.new
      res
    end


    #Add vk.com to address
    def addr(rel = "")
      if(rel.index("vk.com"))
        return rel
      else
        return vkontakte_location() + rel
      end
    end

    #Make POST request
    def post(href, params, skip_encoding = false)
      res = @agent.post(addr(href), params , 'cookie' => @cookie_login).body
      unless skip_encoding
        res.force_encoding("cp1251")
        res = res.encode("utf-8")
      end
      res
    end

    #Make POST request and resolve answer in special way
    def silent_post(href, params)
      resp_post = post(href, params)
      silent(resp_post)
    end

    def silent(resp_post)
      resp = resp_post.split("<!>").find{|str| str.start_with?('{"all":')}.gsub(/^\{\"all\"\:/,'').gsub(/}$/,'').gsub("\r","").gsub("\n","")
      eval("resp=#{resp}")
      resp
    end


    def update_cookies
      remixoldmail = Mechanize::Cookie.new("remixoldmail", "1")
      remixoldmail.domain = ".vk.com"
      remixoldmail.path = "/"
      remixap = Mechanize::Cookie.new("remixap", "1")
      remixap.domain = ".vk.com"
      remixap.path = "/"
      remixchk = Mechanize::Cookie.new("remixchk", "5")
      remixchk.domain = ".vk.com"
      remixchk.path = "/"
      remixdt = Mechanize::Cookie.new("remixdt", "0")
      remixdt.domain = ".vk.com"
      remixdt.path = "/"
      @cookie_login = [remixoldmail,@cookie_login,remixchk].join(";")

    end

    def login
      return true if @cookie_login
      progress "Logging in..."

      if(@@last_user_login )
        diff = Time.new - @@last_user_login
        sleep(@@user_login_interval - diff) if(diff<@@user_login_interval)
      end
      @@last_user_login  = Time.new
      #check captcha
      login_hash = {'op'=>'a_login_attempt','login' => @email}
      captcha_sid = nil
      captcha_key = nil
      while true
        login_hash["captcha_sid"] = captcha_sid if captcha_sid
        login_hash["captcha_key"] = captcha_key if captcha_key
        a_login_attempt = @agent.post(addr('/login.php'),login_hash)
        login_attempt_captcha = a_login_attempt.body.scan(/\"captcha\_sid\"\:\"([^\"]+)\"/)[0]
        if(login_attempt_captcha)
          captcha_sid = login_attempt_captcha[0]
          captcha_key = ask_captcha_internal(captcha_sid)
        else
          break
        end
      end


      #get ip_h
      vkcom = @agent.get(addr("/")).body
      ip_h = vkcom.scan(/ip_h\s*:\s*\"?\'?([^\"\']+)\"?\'/)[0][0]




      #send to login.vk.com
      res_get = @agent.get("https://login.vk.com",{"act"=>"login","success_url"=>"","fail_url"=>"","try_to_login"=>"1",
                                                   "to"=>"","vk"=>"1","al_test"=>"3","from_host"=>"vk.com","from_protocol"=>"http","ip_h"=>ip_h,
                                                   "email"=> @email,"pass"=> @@utf_converter.encode(@password),"expire"=>""
      })



      @agent.cookies.each do |cookie|
        @cookie_login = cookie if cookie.name == "remixsid"
      end

      if @cookie_login



        id = check_login(@email)
        if(id)
          update_session(@email,@cookie_login.value)
          update_cookies
          progress "Done login"
          @uid = id

          return id
        else
          progress :need_phone,self
          progress "Failed"

          return false
        end
      else
        progress "Failed"

        return nil
      end

    end


    def Connect.login?(email,password)
      progress "Get sid..."
      res = nil
      begin
        a = Mechanize.new
        a.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        a.agent.http.retry_change_requests = true
        res = a.post("http://login.userapi.com/auth",{"site" => "2" , "id" => "0" , "fccode" => "0", "fcsid" => "0","login" => "force", "email" => email, "pass" => password }).uri.to_s.scan(/sid\=([^\&]+)/)[0][0]
        res = nil if(res.match(/^\-/))
      rescue
        res = nil
      end
      res
    end

    def Connect.decode_chas(post_decodehash)
      chas = post_decodehash
      chas = (chas[chas.length - 5,5] + chas[4,chas.length - 12])
      chas.reverse!
      chas
    end
  end

  class Music
    attr_accessor :id,:name,:author,:link,:duration,:connect, :delete_hash

    def set(id,name,author,link,duration,connect)
      id_split = id.split("_")
      @user_id = id_split[0]
      @id = id_split[1]
      @name = name
      @connect = connect
      @link = link
      @duration = duration
      @author = author
      self
    end

    def uniq_id
      self.id + "_" + @user_id
    end

    def set_array(array,connect)
      set(array[0].to_s + "_" + array[1].to_s,array[6],array[5],array[2],array[4],connect)
      self
    end

    def to_s
      "#{@author} #{@name}(#{@id})"
    end

    def ==(other)
      self.uniq_id == other.uniq_id
    end

    def hash
      self.id.hash
    end

    def eql?(other)
      self == other
    end

    def download
      return false unless @connect.login
      res = @connect.save(@link,"music","#{@author}_#{@name}_#{id}.mp3")
      progress :music_downloaded,res,self
      res
    end

    def owner
      User.new.set(@user_id,nil,@connect)
    end

    def Music.all(q, connector=nil)
      connect = forсe_login(connector)
      progress "Searching music(#{q}) ..."
      html = Nokogiri::HTML(connect.post('/al_search.php',{"al" => "1", "c[q]" => q, "c[section]" => "audio", "c[sort]" => "2"}).split("<!>")[6].gsub("<!-- ->->",""))
      res = []
      html.xpath("//table").to_a.each do |table|
        dur = table.xpath(".//div[@class='duration fl_r']")
        if(dur.length>0)
          res.push(Music.new.set(
                       table.xpath(".//input[@type='hidden']/@id").text.scan(/audio_info[^\d]*(\d+\_\d+)/)[0][0],
                       table.xpath(".//div[@class='audio_title_wrap']//span").find{|span| (!span["id"].nil?) && span["id"].start_with?("title")}.text,
                       table.xpath(".//div[@class='audio_title_wrap']//a").first.text,
                       table.xpath(".//input[@type='hidden']/@value").text.split(",")[0],
                       dur.text,
                       connect
                   ))
        end
      end
      res
    end

    def Music.one(q, connector=nil)
      Music.all(q, connector)[0]
    end

    def Music.upload(file, connector=nil)
      connect = forсe_login(connector)

      res_total = nil
      if(file.class.name == "Array")
        filenames = file
        many = true
        res_total = []
      else
        filenames = [file]
        many = false
      end
      progress "Music uploading ..."
      filenames.each do |filename|
        safe{
          #Asking for upload parameters and server
          a = connect.post('/audio',{"act" => "new_audio", "al" => "1", "gid" => "0"}).scan(/Upload\.init\(\s*([^\,]+)\s*\,\s*([^\,]+)\s*\,\s*(\{[^\}]*\})/)
          params = JSON.parse(a[0][2])
          params["ajx"] = "1"


          addr = a[0][1].gsub("\"",'').gsub("'",'')
          progress "Uploading " + filename

          #Uploading music
          res = nil
          safe_file_name(filename) do |file_safe|
            f = File.new(file_safe, "rb")
            params["file"] = f
            res = JSON.parse(connect.post(addr,params))
            f.close
          end


          res["act"] = "done_add"
          res["al"] = "1"
          res["artist"] = CGI::unescape(res["artist"])
          res["title"] = CGI::unescape(res["title"])



          #Finishing action
          music_res = connect.post('/audio',res).scan(/\[[^\]]*\]/).find{|x| x.index("vk.com")}
          res_internal = Music.new.set_array(JSON.parse(music_res),connect)
          progress :music_uploaded,res_internal
          if many
            res_total.push(res_internal)
          else
            res_total = res_internal
          end
        }
      end
      res_total
    end

    def remove
      return false unless @connect.login
      return false unless delete_hash
      progress "Deleting music..."
      @connect.post('/audio',{'act' => 'delete_audio', 'aid' => id ,'al' => '1', 'hash' => delete_hash, 'oid' => @user_id, 'restore' => '1'})
      progress :music_removed,@name
    end

    def attach_code
      "#{owner.id}_#{id}"
    end

  end

  class Group
    attr_accessor :connect

    include Vkontakte::PostMaker

    def initialize()
      @open = "unknown"
      @type = "unknown"
      @able_to_comment_post = "unknown"
      @able_to_post = "unknown"
    end

    def able_to_post
      return @able_to_post if @able_to_post != "unknown"
      info
      @able_to_post
    end

    def able_to_comment_post
      return @able_to_comment_post if @able_to_comment_post != "unknown"
      info
      @able_to_comment_post
    end


    def Group.all(query = '', size = 50, offset = 0, hash_qparams = {},  connector=nil)
      Search.all_general(query,size,offset,hash_qparams,connector,"groups") do |query,index,hash_qparams,connector|
        Group.all_offset(query,index,hash_qparams,connector,false)
      end
    end

    def Group.one(query = '', offset = 0, hash_qparams = {}, connector=nil)
      Group.all_offset(query,offset,hash_qparams,connector)[0][0]
    end


    def Group.all_offset(query = '', offset = 0, hash_qparams = {}, connector=nil, force_all = false)
      connect = forсe_login(connector)
      return [[],false,0,nil] unless connect.login

      qhash = {'al' => '1', 'c[q]' => query, 'c[section]' => 'communities', 'offset' => offset.to_s}
      country_name = hash_qparams["Страна"]
      country = @@countries[country_name]

      qhash["c[country]"] = country if country
      User.find_city(hash_qparams,connect)
      city = hash_qparams["Ид города"]
      qhash["c[city]"] = city if city && city != "unknown"

      qhash["c[type]"] = [nil,"Группа","Страница","Встреча"].index(hash_qparams["Тип"]) if hash_qparams["Тип"]



      Search.iterate_search(qhash,offset,connect,force_all) do |group|
        a = group.xpath(".//a")[0]
        href = a["href"].split("?").first
        res =  Group.parse(href,false,connector)
        res.name = a.text
        res
      end
    end

    #Public is "public". "group" means group or event
    def type
      return @type if @type != "unknown"
      info
      @type
    end

    def type=(value)
      @type = value
    end

    def set(id,name=nil,connect=nil)
      @id = id.to_s
      @name = name
      @connect = connect
      self
    end

    def id
      return nil if @id.nil?
      @id = @id.to_s
      return @id if @id =~ /^\d+$/
      info
      @id
    end

    #used for PostMaker
    def id_to_post
      "-#{id}"
    end

    def Group.get_id_by_group_page(resp,type)
      if(type == "group")
        resp.scan(/\"group_id\"\:\"?([\d]*)?/)[0][0]
      else
        resp.scan(/\"public_id\"\:\"?([\d]*)?/)[0][0]
      end
    end

    def name
      return @name if @name
      info
      @name
    end
	
	  def name=(new_name)
      @name = new_name
    end

    def post_hash
      return @post_hash if @post_hash
      info
      @post_hash
    end

    def to_s
      (@name)? "#{@name}(#{@id})" : "#{@id}"
    end

    def uniq_id
      @id
    end

    def ==(other)
      self.uniq_id == other.uniq_id
    end

    def hash
      self.id.hash
    end

    def eql?(other)
      self == other
    end

    def info(connector=nil)
      return if @info
      connect = forсe_login(connector,@connect)
      progress "Fetching group info(#{@id})..."

      resp = connect.get_group(@id,@type)
      @open = resp.index("Закрытая группа").nil? && resp.index("Closed community").nil?  && resp.index("Закрита група").nil?
      @type = (resp.index("group_id"))?"group":"public"
      begin
        @id = Group.get_id_by_group_page(resp, @type)
        @name = Nokogiri::HTML(resp).xpath("//title").text unless @name
      rescue
        @id = nil
        return
      end

      @able_to_post = !resp.index("wall.sendPost").nil?
      @post_hash = User.get_post_hash(resp)
      begin


        if(type == "group")
          @group_hash = resp.scan(Regexp.new("#{@id}\,\s*\'([^\']*)\'"))[0][0]
        else
          @group_hash = resp.scan(/\"?\'?enterHash\"?\'?\s*\:\s*\"?\'?([^\'\"]+)\"?\'?/)[0][0]
        end
      rescue
        @group_hash = nil
      end
      @info = true
    end

    def group_hash
      return @group_hash if @group_hash
      info
      @group_hash
    end



    def Group.id(some_id,connector=nil)
      connect = forсe_login(connector)
      Group.new.set(some_id,nil,connect)
    end

    def Group.parse(href,check_if_exist = true,connector=nil)
      connect = forсe_login(connector)
      res = nil
      if(href.index("/club"))
        res = Group.new.set(href.split("/club").last,nil,connect)
        res.type = "group"
      elsif (href.index("/event"))
        res = Group.new.set(href.split("/event").last,nil,connect)
        res.type = "group"
      elsif (href.index("/public"))
        res = Group.new.set(href.split("/public").last,nil,connect)
        res.type = "public"
      elsif
      id = href.split("/").last
        res = Group.new.set(id,nil,connect)
        if(check_if_exist)
          res.info
          return nil if id.nil?
        end
      end
      return res
    end

    def users
      progress :search_users,self
      User.force_all('', {"Группа"=>id})

    end

    def open
      @open if @open != "unknown"
      info
      @open
    end

    def enter(connector=nil)
      old_connect = @connect
      @connect = forсe_login(connector,@connect)
      @info = nil
      @group_hash = nil
      return unless group_hash
      sleep 1
      progress "Entering group #{id} ..."
      captcha_sid = nil
      captcha_key = nil
      while true

        if(type=="group")
          hash = {"act" => "enter", "al" => "1", "gid" => id , "hash" => group_hash}
          dest = '/al_groups.php'
        else
          hash = {"act" => "a_enter", "al" => "1", "pid" => id , "hash" => group_hash}
          dest = '/al_public.php'
        end
        unless(captcha_key.nil?)
          hash["captcha_sid"] = captcha_sid
          hash["captcha_key"] = captcha_key
        end
        res = connect.post(dest, hash)
        if(res.index("<div"))
          break
        else
          a = res.split("<!>")
          captcha_sid = a[a.length-2]
          captcha_key = connect.ask_captcha_internal(captcha_sid)
        end
      end
      sleep 1



      @connect = old_connect
      progress :group_entered,self
    end

    def leave(connector=nil)
      old_connect = @connect
      @connect = forсe_login(connector,@connect)
      return unless group_hash
      progress "Leaving group (#{id})..."
      if(type=="group")
        @connect.post('/al_groups.php',{"act" => "enter", "context" => "_decline" ,"al" => "1", "gid" => id , "hash" => group_hash})
        @connect.post('/al_groups.php',{"act" => "leave", "al" => "1", "gid" => id , "hash" => group_hash})
      else
        @connect.post('/al_public.php',{"act" => "a_leave", "al" => "1", "pid" => id , "hash" => group_hash})
      end
      @connect = old_connect
      progress :group_leaved,self
    end


    def invite(user,connector=nil)
      old_connect = @connect
      @connect = forсe_login(connector,@connect)
      return unless @connect.able_to_invite_to_group
      if(@connect.last_user_invite)
        diff = Time.new - @connect.last_user_invite
        sleep(@@invite_interval - diff) if(diff<@@invite_interval)
      end
      progress "Inviting to group(#{user.id})..."


      unless(@connect.invite_box[id])
        @connect.invite_box[id] = @connect.post('/al_friends.php', {'act' => 'load_friends_silent', 'al' => '1', 'gid' => id, 'id' => @connect.uid})

        sleep @@invite_interval
      end

      user_row = @connect.invite_box[id].scan(Regexp.new(user.id + '([^\]]+)'))[0]
      if(user_row)
        split = user_row[0].split(",")

        if(split[-2].gsub("'","").gsub("\"","").gsub(/\s/,"") == "0")

          hash = split.last.gsub("'","").gsub("\"","")

          captcha_sid = nil
          captcha_key = nil
          while true
            hash_to_post = {'act' => 'a_invite', 'al' => '1', 'gid' => id, "hash" => hash, "mid" => user.id}
            unless(captcha_key.nil?)
              hash_to_post["captcha_sid"] = captcha_sid
              hash_to_post["captcha_key"] = captcha_key
            end
            res_post =  @connect.post('/al_page.php', hash_to_post)

            if(res_post.index("<!int>1<!>"))
              progress :group_invite,self,user
              break
            elsif(res_post.split("<!>")[-2] == "12")
              @connect.able_to_invite_to_group = false
              progress :phone_invite_to_group,@connect
              break
            elsif(res_post =~ /\d{12}/)
              captcha_sid = res_post[/\d{12}/]
              captcha_key = @connect.ask_captcha_internal(captcha_sid)
            elsif(res_post =~ /per\sday/ || res_post =~ /40\s/)
              @connect.able_to_invite_to_group = false
              progress :able_to_invite_to_group,@connect
              break
            else
              break
            end
          end
          @connect.last_user_invite = Time.new
          @connect = old_connect
        end
      end

    end

  end

  class User
    attr_accessor :me, :connect

    include Vkontakte::PostMaker


    def User.get_id_by_user_page(resp)
      resp.scan(/\'?\"?user_id\"?\'?\:\'?\"?([^\"\,\']*)\"?\'?/)[0][0]
    end

    def User.get_id_by_feed(resp)
      resp.scan(/\"?\'?id\"?\'?\s*\:\s*\"?\'?([^\,\'\"]+)/)[0][0]
    end


    def User.get_post_hash(resp)
      resp.scan(/\"post_hash\"\:\"([^\"]*)\"/)[0][0]
    end

    def id_raw
      @id
    end

    def id
      return nil if @id.nil?
      @id = @id.to_s
      return @id if @id =~ /^\d+$/
      info
      @id
    end

    def id_to_post
      id
    end


    def avatar
      return @avatar if @avatar.to_s != "unknown"
      info unless @avatar_string
      if @avatar_string
        @avatar = Image.parse(@avatar_string)
      else
        @avatar = nil
      end
      @avatar
    end

    def name
      return @name if @name
      info
      @name
    end

    def name=(value)
      @name = value
    end

    def online
      return true if @me
      @info = nil
      info
      @online
    end

    def deleted
      return @deleted if @deleted == true || @deleted == false
      info
      @deleted
    end

    def post_hash
      return @post_hash if @post_hash
      info
      @post_hash
    end

    def friend_hash
      info
      @friend_hash
    end

    def initialize
      @online = "unknown"
      @avatar = "unknown"
      @able_to_comment_post = "unknown"
      @able_to_post = "unknown"
    end

    def set(id,name=nil,connect=nil)
      @id = id.to_s
      @name = name
      @connect = (connect)
      @me = false
      self
    end

    def User.id(id_set,connect=nil)
      res = User.new.set(id_set)
      res.connect = forсe_login(connect)
      res
    end

    def User.login(login,pass,hash = nil)
      User.new.login(login,pass,hash)
    end

    def email
      @connect.email
    end

    #login with current login and password
    def login(login,pass,hash = nil)

      #login_from_session_ok = false
      #if (!hash.nil? && hash.length>0)
      #	@connect = Connect.new
      #	@id = @connect.login_from_cookie(hash)
      #	if(!@id)
      #		@connect = nil
      #	else
      #		login_from_session_ok = true
      #		@me = true
      #	end
      #end
      #unless(login_from_session_ok)
      @connect = Connect.new(login,pass)
      @id = @connect.login
      return @id unless @id
      @me = true
      #end

      self
    end

    def to_s
      (@name)? "#{@name}(#{@id})" : "#{@id}"
    end

    def uniq_id
      @id
    end

    def ==(other)
      self.uniq_id == other.uniq_id
    end

    def hash
      @id.hash
    end

    def eql?(other)
      self == other
    end

    def friends
      return false unless @connect.login
      if(@me)
        progress "List of my friends..."
        friends_json = JSON.parse(@connect.post('/al_friends.php', {"act" => "pv_friends","al" => "1"}).gsub(/^.*\<\!json\>/,''))
        friends_json.map{|x,y| User.new.set(x.gsub('_',''),y[1],@connect)}
      else
        progress "List of friends #{@id}..."
        @connect.silent_post('/al_friends.php', {"act" => "load_friends_silent","al" => "1","id"=>id,"gid"=>"0"}).map{|x| User.new.set(x[0],x[4],@connect)}
      end
    end
	
	def able_to_post
	  return @able_to_post if @able_to_post != "unknown"
      info
      @able_to_post
  end

    def able_to_comment_post
      return @able_to_comment_post if @able_to_comment_post != "unknown"
      info
      @able_to_comment_post
    end

    def info
      return @info if @info
	  return {} if @deleted
      return false unless @connect.login
      return {} unless @connect.login
      progress "Fetching user info #{@id} ..."

      resp = @connect.get_user(@id.to_s)
      if resp.nil?
        @able_to_post = false
        @post_hash = nil
		@info = {}
		@deleted = true
		@name = ""
        return @info
	  else
		@deleted = false
      end
      @online = !resp.index("<b class=\"fl_r\">Online</b>").nil?
      @id = User.get_id_by_user_page(resp) unless @id.to_s =~ /^\d+$/
      html = Nokogiri::HTML(resp)
      name_new = html.xpath("//title").text
      @name = name_new

      
      
      @able_to_post = !resp.index("wall.sendPost").nil?
      @able_to_comment_post = !resp[/wall\.showEditReply\(\'\d+\_\d+\'\)/].nil?
      @post_hash = User.get_post_hash(resp)
      begin
        @avatar_string = html.xpath("//div[@id='profile_avatar']/a[@id='profile_photo_link']")[0]["href"]
      rescue
        @avatar_string = nil
      end
      begin
        @friend_hash = resp.scan(/toggleFriend\(this\,\s*\'?\"?([^\'\"]+)\'?\"?\s*\,\s*1/)[0][0]
      rescue
        @friend_hash = nil
      end

      hash_info = {"статус" => html.xpath("//div[@id='profile_current_info']").text}
      h1 = html.xpath("//div[@class='label fl_l']").map{|div| div.text}
      h2 = html.xpath("//div[@class='labeled fl_l']").map{|div| div.text}
      h1.each_with_index{|name,index| hash_info[name.chomp(":")] = h2[index]}
      @info = hash_info
    end

    def music
      return false unless @connect.login
      progress "List of music #{@id}..."
      q = {"act" => "load_audios_silent","al" => "1"}
      q["id"]=id unless @me

      res = @connect.post('/audio', q )
      music_delete_hash = res.scan(/\"delete_hash\"\:\"([^\"]+)\"/)[0][0]
      @connect.silent(res).map{|x| m = Music.new.set_array(x,@connect);m .delete_hash=music_delete_hash; m}
    end

    def albums
      return false unless @connect.login
      progress "List of albums #{@id} ..."
      offset = 0
      total_res = []

      while true
        hash_params = {"al" => "1", "offset" => offset.to_s, "part" => "1"}
        if(offset==0)
          xml = Nokogiri::HTML(@connect.get("/albums#{id}"))
        else
          xml = Nokogiri::HTML(@connect.post("/albums#{id}",hash_params).split("<!>").find{|x| x.index "<div"})
        end
        add_to_length = 0




        current_res = xml.xpath("//div[@class='cont']/a").inject([]) do |array,a|
          album_delete_hash = nil

          new_album_id = a["href"].scan(/_(\d+)/)[0]
          if(new_album_id)
            new_album_id = new_album_id[0]
            add_to_length -= 1 if (new_album_id == "0" || new_album_id == "00")
            new_album_name = a.xpath(".//div[@class='ge_photos_album fl_l']").text
            array.push(Album.new.set(self,new_album_id,new_album_name,album_delete_hash,connect))
          else
            add_to_length -= 1
          end
          array
        end
        break if current_res.length + add_to_length == 0
        total_res += current_res
        offset+=current_res.length
        offset += add_to_length
      end
      total_res
    end


    def mail(message, friends = true, attach_photo = nil, attach_video = nil, attach_music = nil, title = "",connector=nil)
      connect = forсe_login(connector,@connect)

      return if(!friends && !connect.able_to_send_message)

      if(connect.last_user_mail)
        diff = Time.new - connect.last_user_mail
        sleep(@@mail_interval - diff) if(diff<@@mail_interval)
      end


      progress "Mailing #{@id}..."

      get = connect.get("/write#{id}")

      hash_get = get.scan(/\"?\'?hash\"?\'?\s*\:\s*\"?\'?([^\"\']+)\"\'?/)[0]
      extra_hash_get = get.scan(/\"?\'?extra_hash\"?\'?\s*\:\s*\"?\'?([^\"\']+)\"\'?/)[0]


      return unless hash_get
      return unless extra_hash_get

      hash_get = Connect.decode_chas(hash_get[0])
      extra_hash_get = Connect.decode_chas(extra_hash_get[0])

      sleep @@mail_interval
      captcha_sid = nil
      captcha_key = nil
      while true
        hash = {"act" => "a_send","al" => "1", "chas" => hash_get, "extra_chas" => extra_hash_get, "from" => "write", "message" => message, "title" => title, "to_ids" => id }
        was_attach = false
        hash["media"] = ""
        if(attach_photo)
          attach_photo_out = attach_photo
          if(!attach_photo.start_with?("-"))
            attach_photo_out = ":" + attach_photo
          end
          hash["media"] = "photo#{attach_photo_out}"
          was_attach = true
        end
        if(attach_video)
          attach_video_out = attach_video
          if(!attach_video.start_with?("-"))
            attach_video_out = ":" + attach_video
          end
          hash["media"] += "," if was_attach
          hash["media"] += "video#{attach_video_out}"
          was_attach = true
        end
        if(attach_music)
          hash["media"] += "," if was_attach
          hash["media"] += "audio:#{attach_music}"
          was_attach = true
        end
        unless(captcha_key.nil?)
          hash["captcha_sid"] = captcha_sid
          hash["captcha_key"] = captcha_key
        end
        res = connect.post('/al_mail.php', hash)
        if(res.index("/mail"))
          break
        else
          a = res.split("<!>")
          captcha_sid = a[a.length-2]

          if captcha_sid.to_i == 8
            connect.able_to_send_message = false
            progress :able_to_send_message,connect
            return nil
          end
          captcha_key = connect.ask_captcha_internal(captcha_sid)
        end
      end
      progress :user_mail,self,message
      connect.last_user_mail = Time.new
      res_mail = Mail.new.set(self,res.scan(/r\=(\d+)/)[0][0],message,title,nil,"outbox",connect)
      return res_mail
    end




    def invite(message=nil,connector=nil)
      connect_old = @connect
      @connect = forсe_login(connector,@connect)
      if(@connect.last_user_invite)
        diff = Time.new - @connect.last_user_invite
        sleep(@@invite_interval - diff) if(diff<@@invite_interval)
      end
      return unless (@connect.able_to_invite_friend)
      progress "Inviting #{@id}..."

      @info = nil
      fh = friend_hash
      sleep @@invite_interval
      unless fh
        @connect = connect_old
        return
      end
      captcha_sid = nil
      captcha_key = nil
      while true
        hash = {"act" => "add", "al" => "1", "from" => "profile", "hash" => fh, "mid" => id }
        unless(captcha_key.nil?)
          hash["captcha_sid"] = captcha_sid
          hash["captcha_key"] = captcha_key
        end
        res = @connect.post('/al_friends.php', hash)
        if(res.index("<div"))
          break
        else

          a = res.split("<!>")
          captcha_sid = a[a.length-2]
          if captcha_sid.to_i < 100
            @connect.able_to_invite_friend = false
            progress :able_to_invite_friend,@connect
            @connect = connect_old
            return
          end
          if captcha_sid.length != 12
            @connect = connect_old
            return
          end
          captcha_key = @connect.ask_captcha_internal(captcha_sid)
        end
      end

      @connect.post('/al_friends.php', {"act" => "friend_tt", "al" => "1", "mid" => id})

      @connect.post('/al_friends.php', {"act" => "request_text", "al" => "1", "mid" => id,"hash" => fh, "message" => message}) if message

      progress :user_invite,self
      @connect.last_user_invite = Time.new
      @connect = connect_old
    end


    def uninvite(connector=nil)
      connect_old = @connect
      @connect = forсe_login(connector,@connect)
      progress "Uninviting #{@id}..."
      @connect.post('/al_friends.php', {"act" => "remove", "al" => "1", "mid" => id, "hash" => friend_hash})
      @connect = connect_old
      progress :user_uninvite,self
    end

    def User.can_divide_hash(hash_qparams)
      from =  hash_qparams["От"] || 12
      to =  hash_qparams["До"] || 80
      sex = hash_qparams["Пол"]
      month = hash_qparams["Месяц рождения"]
      day = hash_qparams["День рождения"]
      from != to || sex.nil? || month.nil? || day.nil?
    end

    def User.divide_hash(hash_qparams,size)
      from =  hash_qparams["От"] || 12
      to =  hash_qparams["До"] || 80
      sex = hash_qparams["Пол"]
      month = hash_qparams["Месяц рождения"]
      day = hash_qparams["День рождения"]
      split_method = nil
      if(size > 30000 )
        if(day.nil?)
          split_method = "day"
        elsif(month.nil?)
          split_method = "month"
        elsif(sex.nil?)
          split_method = "sex"
        elsif(from != to)
          split_method = "age"
        end
      elsif(size > 10000)
        if(month.nil?)
          split_method = "month"
        elsif(sex.nil?)
          split_method = "sex"
        elsif(from != to)
          split_method = "age"
        elsif(day.nil?)
          split_method = "day"
        end
      else

        if(sex.nil?)
          split_method = "sex"
        elsif(from != to)
          split_method = "age"
        elsif(month.nil?)
            split_method = "month"
        elsif(day.nil?)
          split_method = "day"

        end
      end




      case split_method
      when "age" then
        split = (to - from) /2
        hash1 = hash_qparams.dup
        hash1["От"] = from
        hash1["До"] = from + split
        hash2 = hash_qparams.dup
        hash2["От"] = from + split + 1
        hash2["До"] = to
        return [hash1,hash2]
      when "sex" then
        hash1 = hash_qparams.dup
        hash1["Пол"] = "Мужской"
        hash2 = hash_qparams.dup
        hash2["Пол"] = "Женский"
        return [hash1,hash2]
      when "month" then
        res = []
        (1..12).each{|m|hash1 = hash_qparams.clone;hash1["Месяц рождения"] = m;res<<hash1}
        return res
      when "day" then
        res = []
        (1..((month.nil?)?31:([nil, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month]))).each{|d|hash1 = hash_qparams.clone;hash1["День рождения"] = d;res<<hash1}
        return res

      else
        return []
      end
    end




    def User.force_all_searches(query = '', size = 50, hash_qparams = {}, connector=nil)
      if(size<=1000) || !User.can_divide_hash(hash_qparams)
        res = safe{User.all_offset(query,0,hash_qparams,connector,true)}
        size = (res[3]>1000)?1000:res[3] if !res.nil? && !res[3].nil?
        progress :search_fit_progress,size
        res_total = [{"params" => hash_qparams,"size" => size}]
        return res_total
      end


      res = safe{User.all_offset(query,0,hash_qparams,connector,true)}
      return [] unless res
      sleep 1
      progress "Searching users #{query} length #{res[3]}..."
      if(res[3].nil?)
        return []
      elsif(res[3] == 0)
        sleep 1
        return []
      elsif(res[3]<=1000)
        sleep 1
        #ret =  User.all(query, res[3], 0, hash_qparams)
        progress :search_fit_progress,res[3].to_s
        ret = [{"params" => hash_qparams,"size" => res[3]}]
        return ret

      end

      progress :search_divide_progress,res[3].to_s
      res_total = []

      User.divide_hash(hash_qparams,res[3]).each do |hash_divided|
        all_length = res_total.inject(0){|sum,h|sum += h["size"];sum}
        if(size - all_length>0)
          res_total +=(User.force_all_searches(query,size - all_length,hash_divided,connector))
        end
      end
      res_total
    end




    def User.all(query = '', size = 50, offset = 0, hash_qparams = {},  connector=nil)
      Search.all_general(query,size,offset,hash_qparams,connector,"users") do |query,index,hash_qparams,connector|
        User.all_offset(query,index,hash_qparams,connector,false)
      end
    end

    def User.one(query = '', offset = 0, hash_qparams = {}, connector=nil)
      User.all_offset(query,offset,hash_qparams,connector)[0][0]
    end

    #Make query to resolve name of city to id
    def User.find_city(hash_qparams,connect)
      country_name = hash_qparams["Страна"]
      country = @@countries[country_name]
      city = hash_qparams["Город"]
      city_id = hash_qparams["Ид города"]
      if(city && country && !city_id)

        res_city = connect.post('/select_ajax.php',{"act" => "a_get_cities", "country" => country.to_s, "str" => city},true)
        city_id = res_city.scan(/\d+/)[0]
        if city_id
          hash_qparams["Ид города"] = city_id
        else
          hash_qparams["Ид города"] = "unknown"
        end
      end
    end




    def User.all_offset(query = '', offset = 0, hash_qparams = {}, connector=nil, force_all = false)
      connect = forсe_login(connector)
      return [[],false,0,nil] unless connect.login

      qhash = {'al' => '1', 'c[q]' => query, 'c[section]' => 'people', 'offset' => offset.to_s}
      country_name = hash_qparams["Страна"]
      country = @@countries[country_name]

      qhash["c[country]"] = country if country
      User.find_city(hash_qparams,connect)
      city = hash_qparams["Ид города"]
      qhash["c[city]"] = city if city && city != "unknown"

      qhash["c[sex]"] = "2" if(hash_qparams["Пол"] == "Мужской")
      qhash["c[sex]"] = "1" if(hash_qparams["Пол"] == "Женский")

      age_from = hash_qparams["От"]
      qhash["c[age_from]"] = age_from if age_from

      age_to = hash_qparams["До"]
      qhash["c[age_to]"] = age_to if age_to

      qhash["c[online]"] = "1" if(hash_qparams["Онлайн"] == "Да")


      qhash["c[name]"] = (hash_qparams["По имени"] == "Да")? "1":"0"
      qhash["c[sort]"] = "1" if (hash_qparams["По дате"] == "Да")
      qhash["c[group]"] = (hash_qparams["Группа"]) if (hash_qparams["Группа"])
      qhash["c[bmonth]"] = hash_qparams["Месяц рождения"] if hash_qparams["Месяц рождения"]
      qhash["c[bday]"] = hash_qparams["День рождения"] if hash_qparams["День рождения"]
      qhash["c[status]"] = [nil,"Не женат","Есть подруга","Помолвлен","Женат","Влюблён","Всё сложно","В активном поиске"].index(hash_qparams["Семейное положение"]) if hash_qparams["Семейное положение"]

      Search.iterate_search(qhash,offset,connect,force_all) do |human|
        a = human.xpath(".//a")[0]
        href = a["href"]
        href = href.scan(/\/id(\d+)/)[0][0] if href =~ /\/id\d+/
        href.gsub!("/","")
        User.new.set(href,a.text,connect)
      end
    end

    def firstname
      name.to_s.split(/\s+/).first
    end

    def User.parse(href)
      if href.index("/id")
        id = href.split("/id")[1]
      else
        id = href.split("/").last
      end
      User.id(id)
    end


    def groups
      return false unless @connect.login
      progress "List of groups #{@id}..."
      res = []
      json_text = @connect.post('/al_groups.php', {"act" => "get_list", "al" => "1", "mid" => id, "tab" => "groups"}).split("<!>").find{|x| x.index("<!json>")}
      return [] if json_text.nil?
      JSON.parse(json_text.gsub("<!json>","")).each do |el|
        res.push Group.new.set(el[2].to_s,el[0],@connect)
      end
      res.uniq!
      res

    end

    def balance
      return false unless @connect.login
      res_post = @connect.post("/al_gifts.php",{"act"=>"get_money","al"=>"1"})
      html_text = res_post.split("<!>").find{|x| x.index("<div")}
      html = Nokogiri::HTML(html_text)
      text = html.xpath("//div[@class = 'payments_summary_cont']").text.gsub(/[^\d]/,"")
      text.to_i
    end


  end

  class Mail
    attr_accessor :id, :user, :text, :title, :delete_hash, :type, :connect
    def set(user,id,text,title,delete_hash,type,connect)
      @id = id
      @text = text
      @title = title
      @connect = connect
      @user = user
      @type = type
      @delete_hash = delete_hash
      self
    end

    def remove
      return false unless connect.login
      progress "Delete mail #{id} ..."
      delete_hash = (connect.get("/mail?act=show&id=#{id}")).scan(/\'?\"?mark_hash\'?\"?\s*\:\s*\'?\"?([^\"\'\,]*)/)[0][0]
      connect.post("/al_mail.php",{"act" => "a_delete", "al" => "1", "from"=>type,"hash"=>delete_hash,"id" => id})
      progress :mail_remove,self
    end


    def uniq_id
      self.id + "_" + self.user.id
    end

    def ==(other_user)
      self.uniq_id == other_user.uniq_id
    end

    def hash
      self.id.hash
    end
  end

  class Post
    attr_accessor :id, :user_or_group, :text, :delete_hash, :like_hash, :post_hash, :type, :connect

    def set(user_or_group,id,text,delete_hash,like_hash,post_hash,type,connect)
      @id = id
      @text = text
      @connect = connect
      @user_or_group = user_or_group
      @delete_hash = delete_hash
      @post_hash = post_hash
      @like_hash = like_hash
      @type = type
      self
    end

    def comment(message,connector = nil)
      connect = forсe_login(connector,@connect)
      return unless connect.login
      return unless post_hash
      return unless connect.able_to_post_on_wall
      progress "Comment to post #{id} ..."

      if(connect.last_user_post)
        diff = Time.new - @connect.last_user_post
        sleep(@@post_interval - diff) if(diff<@@post_interval)
      end

      captcha_sid = nil
      captcha_key = nil
      while true
        hash = {"act" => "post", "al" => "1","message"=>message,"hash"=>post_hash,"reply_to"=>"#{user_or_group.id_to_post}_#{id}","reply_to_msg"=>"","reply_to_user"=>"0","start_id"=>"","type"=>"all"}

        unless(captcha_key.nil?)
          hash["captcha_sid"] = captcha_sid
          hash["captcha_key"] = captcha_key
        end
        res = connect.post("/al_wall.php",hash)
        if(res[/\<\!\>\d{12}\<\!\>/])
          a = res.split("<!>")
          captcha_sid = a[a.length-2]

          captcha_key = connect.ask_captcha_internal(captcha_sid)

        elsif(res.split("<!>")[-2] == "11")
          connect.able_to_post_on_wall = false
          progress :phone_to_post,connect
          return
        elsif(res.split("<!>")[-2] == "8")
          connect.able_to_post_on_wall = false
          progress :able_to_post_on_wall,connect
          return
        else
          break
        end
      end
      connect.last_user_post = Time.new
      progress :post_comment,user_or_group,message

    end

    def Post.parse_html(table,user_or_group,post_hash,type,connect)

      id_of_post = table.to_s.scan(Regexp.new("#{user_or_group.id_to_post}\\_(\\d+)"))[0][0]

      delete_hash = table.to_s.scan(/wall\.deletePost[^\,]*\,\s*\'([^\']*)\'/)[0]
      delete_hash = (delete_hash)? delete_hash[0]:nil

      like_hash = table.to_s.scan(/wall\.like[^\,]*\,\s*\'([^\']*)\'/)[0]
      like_hash = (like_hash)? like_hash[0]:nil

      text_of_post = table.xpath(".//div[@id='wpt#{user_or_group.id_to_post}_#{id_of_post}']")
      text_of_post = (text_of_post.length>0)? (text_of_post[0].text):nil

      Post.new.set(user_or_group,id_of_post,text_of_post,delete_hash,like_hash,post_hash,type,connect)

    end



    def uniq_id
      self.id + "_" + self.user_or_group.id
    end

    def ==(other_user)
      self.uniq_id == other_user.uniq_id
    end

    def hash
      self.id.hash
    end


    def like(connector=nil)
      connect = forсe_login(connector,@connect)
      return false unless connect.login
      return false unless like_hash
      progress "Like post #{id} ..."

      if(connect.last_user_like)
        diff = Time.new - connect.last_user_like
        sleep(@@like_interval - diff) if(diff<@@like_interval)
      end

      captcha_sid = nil
      captcha_key = nil
      while true
        hash = {"act" => "a_do_like", "al" => "1","from"=>"wall_page","hash"=>like_hash,"object"=>"wall#{user_or_group.id_to_post}_#{id}","wall"=>"1"}


        unless(captcha_key.nil?)
          hash["captcha_sid"] = captcha_sid
          hash["captcha_key"] = captcha_key
        end
        res = connect.post("/like.php",hash)
        if(res[/\d{12}/])
          a = res.split("<!>")
          captcha_sid = a[a.length-2]

          captcha_key = connect.ask_captcha_internal(captcha_sid)

        else
          break
        end
      end
      connect.last_user_like = Time.new
      progress :post_like,self
    end

    def unlike(connector=nil)
      connect = forсe_login(connector,@connect)
      return false unless connect.login
      return false unless like_hash
      progress "Unlike post #{id} ..."
      res_post = connect.post("/like.php",{"act" => "a_do_unlike", "al" => "1","from"=>"wall_page","hash"=>like_hash,"object"=>"wall#{user_or_group.id_to_post}_#{id}","wall"=>"1"})
      progress :post_unlike,self
    end

    def remove
      return false unless @connect.login
      return false unless delete_hash
      progress "Delete post #{id} ..."
      res_post = @connect.post("/al_wall.php",{"act" => "delete", "al" => "1","from"=>"wall","hash"=>delete_hash,"post"=>"#{user_or_group.id_to_post}_#{id}","root"=>"0"})
      progress :post_remove,self
    end

    def to_s
      "#{text}(#{@id})"
    end
  end

  class Album
    attr_accessor :id, :user, :name, :connect, :delete_hash


    def Album.parse(href)
      href = href.split("?").first
      id_complex = href.split("/album").last.split("_")
      user = User.id(id_complex.first)
      res = user.albums.find{|x| x.id == id_complex.last}
      res || Album.new.set(user,id_complex.last,"",nil,user.connect)

    end


    def set(user,id,name,delete_hash,connect)
      @id = id
      @name = name
      @connect = connect
      @user = user
      @delete_hash = delete_hash
      self
    end

    class << self
      # возвращает пути к списку альбомов из файла
      def get_from_file
        File.readlines("../../settings/albums.txt")
      end
    end

    def to_s
      "#{name}(#{@id})"
    end

    def uniq_id
      self.id + "_" + self.user.id
    end

    def ==(other_user)
      self.uniq_id == other_user.uniq_id
    end

    def hash
      self.id.hash
    end

    def eql?(other)
      self == other
    end

    def Album.create(name, description="", connector=nil)
      connect = forсe_login(connector)

      progress "Creating album #{name}..."
      hash = connect.post('/al_photos.php',{"al" => "1", "act" => "new_album_box"}).scan(/hash\:\s*\'([^\']+)\'/)[0][0]
      res = connect.post('/al_photos.php',{"al" => "1", "act" => "new_album", "comm" => "0", "view" => "0", "only" => "false" , "oid" => connect.uid, "title" => name, "desc" => description, "hash" => hash })
      album_id = res.scan(/\_(\d+)/)[0][0]
      res_album = Album.new.set(User.new.set(connect.uid), album_id ,name,nil,connect)
      progress :album_created, res_album
      res_album
    end


    def upload(file,description)
      return false unless @connect.login
      res_total = nil

      if(file.class.name == "Array")
        filenames = file
        many = true
        res_total = []
      else
        filenames = [file]
        many = false
      end

      filenames.each do |filename|
        safe{
          progress "Uploading #{filename} ..."
          #Asking for upload parameters and server
          #post = connect.post('/al_photos.php',{"__query" => "album#{user.id}_#{id}", "al" => "-1", "al_id" => user.id})
          #hash = post.scan(/hash[^\da-z]+([\da-z]+)/)[0][0]
          #rhash = post.scan(/rhash[^\da-z]+([\da-z]+)/)[0][0]
          #addr = post.scan(/flashLiteUrl\s*\=\s*([^\;]+)/)[0][0].gsub("\"",'').gsub("'",'').gsub("\\",'')

          get = connect.get("/album#{user.id}_#{id}?act=add")
          addr = get.scan(/\'?\"?url\"?\'?\s*\:\s*\'?\"?([^\'\"\,]+)/)[0][0]
          fields = JSON.parse(get.scan(/\'?\"?fields\'?\"?\s*\:\s*(\{[^\}]+\})/)[0][0])


          params = {"oid" => user.id, "aid" => id, "gid" => "0", "mid" => user.id, "hash" => fields["hash"], "rhash" => fields["rhash"], "act" => "do_add", "ajx" => "1"}
          res = nil
          safe_file_name(filename) do |file_safe|
            f = File.new(file_safe, "rb")
            params["photo"] = f

            #Uploading photo
            res = connect.post(addr,params)
            f.close
          end

          #Asking for photo parameters
          hash = res.scan(/hash\=([^\&]+)/)[0][0]
          photos = res.scan(/photos\=([^\&]+)/)[0][0]
          server = res.scan(/server\=([^\&]+)/)[0][0]


          params = {"photos" => photos,"server" => server,"from" => "html5","context" => "1", "al" => "1", "aid" => id, "gid" => "0", "mid" => user.id, "hash" => hash, "act" => "done_add"}
          res = connect.post('/al_photos.php',params)
          hash = res.scan(/deletePhoto[^\,]+\,\s*([^\)]+)/)[0][0].gsub("\"",'').gsub("'",'')
          res_internal = Image.new.set(self,res.split("<!>").last.split("_").last,res.scan(/src\=\s*\"([^\"]+)\"/)[0][0].gsub("\"","").gsub("'",""),hash,true,false,connect)
          if many
            res_total.push(res_internal)
          else
            res_total = res_internal
          end
          progress :photo_uploaded,res_internal
        }
      end
      res_total
    end


    def photos
      return false unless @connect.login
      progress "List of photos from #{name}..."

      res = []
      num = 0
      b = false
      while(true)
        post = @connect.post('/al_photos.php',{"al" => "1","direction" => "1","offset"=>num.to_s, "act" => "show", "list" => "album#{user.id}_#{@id}"})
        begin
        json = JSON.parse(post.split("<!json>").last.split("<!>").first)
        rescue
          json = ""
        end
        num += json.length
        break if json.length == 0
        json.inject(res) do |array,el|
          id = el['id'].split("_").last
          if(array.find{|p|p.id == id})
            b = true
            break
          end
          array.push(Image.new.set(self,id,el['x_src'],el['hash'],!(el["actions"]["comm"].nil?),el["liked"].to_s == "1",connect))
          array
        end
        break if b
      end
      res
    end


    def remove
      return false unless @connect.login

      resp = @connect.get("/al_photos.php?__query=album#{user.id}_#{id}&act=edit&al=-1&al_id=155366142")
      if(resp && resp.index("albumhash"))
        delete_hash =  resp.scan(/albumhash\s*\:\s*\'([^\']+)\'/)[0][0]
      end
      return unless delete_hash
      progress "Removing album #{id}..."
      name_save = name
      @connect.post('/al_photos.php',{"act" => "delete_album", "al" => "1", "album" => "#{user.id}_#{id}", "hash" => delete_hash})
      progress :album_removed,name_save

    end

  end

  class Image
    attr_accessor :id, :album, :connect, :link, :hash_vk, :open, :liked
    def set(album,id,link,hash_vk,open,liked,connect)
      @id = id
      @album = album
      @connect = connect
      @link = link
      @open = open
      @liked = liked
      @hash_vk = hash_vk
      self
    end

    def attach_code
      "#{album.user.id}_#{id}"
    end

    def Image.get_attach_code(href)
      href.gsub!("%2F","/")
      res = href.scan(/(photo\-?\d+\_\d+(\/wall\-?\d+\_\d+)?)/)[0]
      if(res)
        res = res[0]
        res.gsub!("photo","")
      end
      res
    end

    def Image.upload_mail(file,connector = nil)
      Image.upload_universal(file,"-3",connector)

    end

    def Image.upload_mail(file,connector = nil)
      connect = forсe_login(connector)
      return false unless connect.login
      res_total = nil

      if(file.class.name == "Array")
        filenames = file
        many = true
        res_total = []
      else
        filenames = [file]
        many = false
      end

      filenames.each do |filename|
        safe{
          progress "Uploading #{filename} ..."


          get = connect.post("/photos.php",{"act" => "a_choose_photo_box", "al" => "1", "mail_add" => "1", "scrollbar_width" => "16"})

          scan = get.scan(/Upload\.init\(\'?\"?choose_photo_upload\'?\"?\s*\,\s*\'?\"?([^\'\"]+)\'?\"?\s*,\s*(\{[^\}]+\})/)[0]
          addr = scan[0]
          fields = JSON.parse(scan[1])


          params = {"oid" => connect.uid, "aid" => "-3", "gid" => "0", "mid" => connect.uid, "hash" => fields["hash"], "rhash" => fields["rhash"], "act" => "do_add", "ajx" => "1"}
          res = nil
          safe_file_name(filename) do |file_safe|
            f = File.new(file_safe, "rb")
            params["photo"] = f

            #Uploading photo
            res = connect.post(addr,params)
            f.close
          end

          #Asking for photo parameters
          hash = res.scan(/hash\=([^\&]+)/)[0][0]
          photos = res.scan(/photos\=([^\&]+)/)[0][0]
          server = res.scan(/server\=([^\&]+)/)[0][0]


          params = {"photos" => photos,"server" => server,"from" => "html5","context" => "1", "al" => "1", "aid" => "-3", "gid" => "0", "mid" => connect.uid, "hash" => hash, "act" => "choose_uploaded"}
          res = connect.post('/al_photos.php',params)

          res_internal = res.split("<!>")[5]
          if many
            res_total.push(res_internal)
          else
            res_total = res_internal
          end
          progress :photo_uploaded,res_internal
        }
      end
      res_total
    end

    def Image.parse(href)
      id_complex = href.scan(/photo\d+\_\d+/)[0]
      id_complex = id_complex.gsub("photo","")
      id_complex_split = id_complex.split("_")
      connect = forсe_login(nil,nil)
      resp = connect.post('/al_photos.php', {"act" => "show","al" => "1","photo" => id_complex})
      json = JSON.parse(resp.split("<!>").find{|x| x.index('"id"')}.gsub("<!json>","")).find{|x| x["id"] == id_complex}
      album_response = Album.parse("/" + resp.split("<!>").find{|x| x.index("album")})
      Image.new.set(album_response,id_complex_split.last,json["x_src"],json["hash"],!(json["actions"]["comm"].nil?),json['liked'].to_s == '1',connect)
    end

    def hash_vk_for_user(connector)
      resp = connector.connect.post('/al_photos.php', {"act" => "show","al" => "1","photo" => "#{album.user.id}_#{id}"})
      json = JSON.parse(resp.split("<!>").find{|x| x.index('"id"')}.gsub("<!json>","")).find{|x|x["id"]=="#{album.user.id}_#{id}"}
      [json["hash"],json["liked"]]
    end

    def to_s
      "#{@id}"
    end

    def uniq_id
      self.id + "_" + self.album.id + "_" + self.album.user.id
    end

    def ==(other)
      self.uniq_id == other.uniq_id
    end

    def hash
      self.id.hash
    end

    def eql?(other)
      self == other
    end

    def download
      return false unless @connect.login
      path = File.join(Vkontakte::loot_directory, "images")
      Dir::mkdir(path) unless File.exists?(path) && File.directory?(path)
      res = @connect.save(@link,"images/#{@album.name}","#{id}.jpg")
      progress :image_downloaded,res,self
    end


    def remove
      return false unless @connect.login
      progress "Deleting photo #{id}..."
      album_copy = album
      @connect.post("/al_photos.php",{"act" => "delete_photo", "al" => "1", "hash" => hash_vk, "photo" => "#{album.user.id}_#{id}"})
      progress :image_removed,album_copy
    end


    def mark(users)
      return false unless @connect.login


      if(users.class.name == "Array")
        users_array = users
      else
        users_array = [users]
      end

      users_array.each do |user_it|
        safe{
          if(@connect.last_user_mark_photo)
            diff = Time.new - @connect.last_user_mark_photo
            sleep(@@photo_mark_interval - diff) if(diff<@@photo_mark_interval)
          end
          progress "Marking #{user_it.to_s}..."
          @connect.post('/al_photos.php', {"act" => "add_tag", "al" => "1", "hash" => hash_vk, "mid" => user_it.id, "photo" => "#{album.user.id}_#{id}", "x2" => "1.00000000000000", "x" => "0.00000000000000","y2" => "1.00000000000000", "y" => "0.00000000000000"})
          @connect.last_user_mark_photo = Time.new
          progress :image_marked,user_it
        }
      end
    end

    def unmark(users)
      return false unless @connect.login

      resp_tags = @connect.post('/al_photos.php', {"act" => "show","al" => "1","photo" => "#{album.user.id}_#{id}"})
      tagged = JSON.parse(resp_tags.split("<!>").find{|x| x.index('"id"')}.gsub("<!json>",""))[0]["tagged"]


      if(users.class.name == "Array")
        users_array = users
      else
        users_array = [users]
      end
      users_array.each do |user_it|
        safe{
          progress "Unmarking #{user_it.to_s}..."
          next if tagged.class.name == "Array"
          tag = tagged[user_it.id]
          next unless tag
          @connect.post('/al_photos.php', {"act" => "delete_tag", "al" => "1", "hash" => hash_vk, "tag" => tag, "photo" => "#{album.user.id}_#{id}", "x2" => "1.00000000000000", "x" => "0.00000000000000","y2" => "1.00000000000000", "y" => "0.00000000000000"})
          progress :image_unmarked,user_it
        }
      end
    end

    def like(connector=nil)
      connect = forсe_login(connector,@connect)
      return unless connect.able_to_like
      if(connector)
         res_current = hash_vk_for_user(connector)
         hash_current = res_current[0]
         return if res_current[1].to_s == "1"
      else
        hash_current = hash_vk
        return if @liked
      end

      return false unless connect.login
      return false unless hash_current
      if(connect.last_user_like)
        diff = Time.new - connect.last_user_like
        sleep(@@like_interval - diff) if(diff<@@like_interval)
      end

      progress "Like photo #{id}..."
      captcha_sid = nil
      captcha_key = nil

      while true
        hash = {"act" => "a_do_like", "al" => "1","from"=>"photo_viewer","hash"=>hash_current,"object"=>"photo#{album.user.id}_#{id}"}


        unless(captcha_key.nil?)
          hash["captcha_sid"] = captcha_sid
          hash["captcha_key"] = captcha_key
        end
        res = connect.post("/like.php",hash)
        if(res[/\d{12}/])
          a = res.split("<!>")
          captcha_sid = a[a.length-2]

          captcha_key = connect.ask_captcha_internal(captcha_sid)

        elsif(res.index("<!int>"))
          break
        else
          progress :able_to_like,connect
          connect.able_to_like = false
          return
        end
      end

      connect.last_user_like = Time.new
      @liked = true if connector
      progress :image_like,self
    end

    def post(message,connector=nil)

      connect = forсe_login(connector,@connect)
      return unless @connect.able_to_post_on_wall

      if(connector)
        hash_current = hash_vk_for_user(connector)[0]
        sleep @@post_interval
      else
        hash_current = hash_vk
      end

      return false unless connect.login
      return false unless hash_current


      captcha_sid = nil
      captcha_key = nil

      if(connect.last_user_post)
        diff = Time.new - @connect.last_user_post
        sleep(@@post_interval - diff) if(diff<@@post_interval)
      end
      progress "Post to photo #{id}..."

      while true
        hash = {"act" => "post_comment", "al" => "1","fromview"=>"1","hash"=>hash_current,"comment"=>message,"photo" => "#{album.user.id}_#{id}"}


        unless(captcha_key.nil?)
          hash["captcha_sid"] = captcha_sid
          hash["captcha_key"] = captcha_key
        end
        res = connect.post("/al_photos.php",hash)
        if(res.index("<div"))
          break
        else
          a = res.split("<!>")
          captcha_sid = a[a.length-2]
          if(captcha_sid.to_i == 8)
            connect.able_to_post_on_wall = false
            progress :able_to_post_on_wall,connect
            return
          end
          break if captcha_sid.to_i < 100
          captcha_key = connect.ask_captcha_internal(captcha_sid)
        end
      end
      connect.last_user_post = Time.new
      progress :image_post,self
    end


    def unlike(connector=nil)
      connect = forсe_login(connector,@connect)
      if(connector)
        res_current = hash_vk_for_user(connector)
        hash_current = res_current[0]
        return if res_current[1].to_s != "1"
      else
        hash_current = hash_vk
        return unless @liked
      end


      return false unless connect.login
      return false unless hash_current
      if(connect.last_user_like)
        diff = Time.new - @connect.last_user_like
        sleep(@@like_interval - diff) if(diff<@@like_interval)
      end
      progress "Unlike photo #{id}..."
      connect.post("/like.php",{"act" => "a_do_unlike", "al" => "1","from"=>"photo_viewer","hash"=>hash_current,"object"=>"photo#{album.user.id}_#{id}"})
      connect.last_user_like = Time.new

      progress :image_unlike,self
      @liked = false if connector
    end


  end

  class Video
    attr_accessor :id, :user
    def Video.parse(href)
      id_complex = href.scan(/video\d+\_\d+/)[0]
      id_complex = id_complex.gsub("video","")
      id_complex_split = id_complex.split("_")
      res_video = Video.new
      res_video.id = id_complex_split[1]
      res_video.user = User.id(id_complex_split[0])
      res_video

    end
    def attach_code
      "#{user.id}_#{id}"
    end

    def Video.get_attach_code(href)
      href.gsub!("%2F","/")
      res = href.scan(/(video\-?\d+\_\d+\/?)/)[0]
      if(res)
        res = res[0]
        res.gsub!("video","")
        unless(res.start_with?("-"))
          res.gsub!("%2F","")
        end
      end
      res
    end

    def Video.upload_youtube(code,title,connector = nil)
      connect = forсe_login(connector)
      upload_box = connect.post("/al_video.php", {"act" => "upload_box", "al" => "1", "oid" => connect.uid})
      hash_scan = upload_box.scan(/\'?\"?act\'?\"?\s*\:\s*\'?\"?save_external\'?\"?\s*\,\s*hash\s*\:\s*\'?\"?([^\"\']+)\"?\'?/)[0]
      html = Nokogiri::HTML(upload_box.split("<!>").find{|x| x.index("<div")})
      hash_prepare = html.xpath("//form[@target = 'video_share_frame']/input[@name = 'hash']")[0]["value"]
      rhash_prepare = html.xpath("//form[@target = 'video_share_frame']/input[@name = 'rhash']")[0]["value"]
      action = html.xpath("//form[@target = 'video_share_frame']/@action").text

      prepare_res = connect.post(action,{"url" => "http://www.youtube.com/watch?v=#{code}","act" => "parse_share", "from_host" => "vk.com", "mid" => connect.uid, "hash" => hash_prepare, "rhash" => rhash_prepare},true )
      extra = prepare_res.scan(/extra\s*:\s*([^\,]+)/)[0][0]
      extra_data = prepare_res.scan(/extraData\s*:\s*\'([^\']+)/)[0][0]
      images = prepare_res.scan(/images\s*:\s*\[\'([^\']+)/)[0][0]

      return unless hash_scan
      hash = hash_scan[0]


      res = connect.post("/al_video.php", {"act"  => "save_external", "al"  => "1" , "description" => "",
                                           "domain" => "www.youtube.com", "hash" => hash,
                                           'extra' => extra,
                                           'extra_data' => extra_data,
                                           "image_url" => "http://img.youtube.com/vi/#{code}/maxresdefault.jpg",
                                           "oid" => connect.uid,
                                           "privacy_video" => "0",
                                           "privacy_videocomm" => "0",
                                           "image_url" => images,
                                           "share_title" => title,
                                           "title" => title,
                                           "to_video" => "1",
                                           "url" => "http://www.youtube.com/watch?v=#{code}"})
      json = JSON.parse(res.split("<!>").find{|x| x.index("<!json>")}.gsub("<!json>",""))

      res_video = Video.new
      res_video.id = json["video_id"]
      res_video.user = User.id(connect.uid)
      res_video

    end

  end

  class Search

    def Search.all_general(query = '', size = 50, offset = 0, hash_qparams = {},  connector=nil, label = "users")
      User.find_city(hash_qparams,forсe_login(connector))
      progress "Searching #{label} #{query}..."
      res_all = []
      puts hash_qparams
      index = offset
      while true do

        res = yield(query,index,hash_qparams,connector)
        sleep 0.3
        progress "Searching #{label} #{query} offset #{index}..."
        json_has_more = res[1]
        json_offset = res[2]
        json_length = res[3]
        res = res[0]
        #index += 20 if index==0
        #index += 20
        index = json_offset


        res_all += res
        if !json_has_more || res_all.length>=size.to_i
          break
        end
      end
      res_all = res_all[0,size] if(res_all.length>size)

      return res_all
    end

    #used as part(20 or 40) of search people or group
    def Search.iterate_search(qhash,offset,connect,force_all)
      res = nil
      seconds_sleep = 50

      while true
        res = connect.post('/al_search.php',qhash)
        json_valid = false
        json_string = res.split("<!>").find{|x| x.index("<!json>")==0}

        json = JSON.parse(json_string.gsub("<!json>",""))
        json_has_more = json["has_more"]
        json_offset = json["offset"]
        json_length = nil
        if(json["summary"])
          json_length_string = json["summary"].gsub(/\<[^\>]+\>/,"").gsub(/[^\d]+/,'')
          if (json_length_string.length != 0)
            json_length = json_length_string.to_i
            json_valid = true
          end

        end
        res_array = []
        if(offset>0 || json_valid || !force_all)
          html_text = res.split("<!>").find{|x| x.index '<div'}
          return [[],false,0,nil] unless html_text
          html = Nokogiri::HTML(html_text)

          html.xpath("//div[@class='info fl_l']").each do |human|
            res_yield = yield(human)

            res_array.push(res_yield) if res_yield

          end
        end
        if(res_array.length > 0)
          return [res_array,json_has_more,json_offset,json_length]
        end
        return  [[],false,0,nil] if(seconds_sleep>50)
        progress "sleep #{seconds_sleep}"
        sleep seconds_sleep
        seconds_sleep *= 4
      end
    end

  end


end
