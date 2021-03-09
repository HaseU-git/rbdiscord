require "date"
require "uri"
require "net/https"
require "json"
require "discordrb"
require "iso_country_codes"

TOKEN = "TOKEN"
CLIENT_ID = "CLIENT_ID"
BASE_URL = "https://covidapi.info/api/v1"

def iso_validator(country_str)
    ret = false
    for country in IsoCountryCodes.all
        if country.alpha3 == country_str.upcase
            ret = country.alpha3
            break
        end
    end
    return ret
end

def date_validator(date_str)
  date_ary = date_str.split(/-/)
  if date_ary.size == 3 && Date.valid_date?(date_ary[0].to_i, date_ary[1].to_i, date_ary[2].to_i)
     Date.parse(date_str)
  else
     return false
  end
end

def single_date_func(content, country)
    begin
        temp_res = Net::HTTP.get_response(URI.parse("#{BASE_URL}/latest-date"))
        temp_res.value
        if (Date.parse("2020-01-22") <= Date.parse(content.date_str)) && (Date.parse(content.date_str) <= Date.parse(temp_res.body))
          content.res = Net::HTTP.get_response(URI.parse("#{BASE_URL}/country/#{country}/#{content.date_str}"))
          content.res.value
        else
          content.err_msg = "[error] date is out of range"
        end
    rescue => err
        content.err_msg = "[error]" + err.message
    end
    return content
end

def check_yesterday(content, country)
    begin
    content.date_str = (Date.today() - 1).to_s
    content.res = Net::HTTP.get_response(URI.parse("#{BASE_URL}/country/#{conutry}/#{content.date_str}"))
    content.res.value
    rescue
        begin
            temp_res = Net::HTTP.get_response(URI.parse("#{BASE_URL}/latest-date"))
            content.date_str = temp_res.body
            content.res = Net::HTTP.get_response(URI.parse("#{BASE_URL}/country/#{country}/latest"))
            content.res.value
            content.update_ret("Sorry, yesterday data is not avaliable yet.
Here is the latest data.
")
        rescue => err
            content.err_msg = "[error]" + err.message
        end
    end
    return content
end

def make_ans(content)
    begin
        temp = JSON.parse(content.res.body)["result"][content.date_str.to_s]
        content.confirmed = temp["confirmed"]
        content.deaths = temp["deaths"]
        content.recovered = temp["recovered"]
    rescue
        content.err_msg = "[error] JSON format is invalid."
    end
    return content
end

def main_func(content, args)
    if (args.size() == 0) then
        content.err_msg = "[error] Arguments are required."
    elsif (!(country_code = iso_validator(args[0].to_s))) then
        content.err_msg = "[error] Country code is invalid."
    elsif (args.size() == 1) then
        content = check_yesterday(content, country_code)
        content.err_msg ? nil : (content = make_ans(content))
    elsif (args.size() == 2) then
        if (!(date_validator(args[1].to_s))) then
            content.err_msg = "[error] The date format is invalid."
        else
            content.date_str = args[1].to_s
            (content.err_msg) ? nil : (content = single_date_func(content, country_code))
            (content.err_msg) ? nil : (content = make_ans(content))
        end
    else
        content.err_msg = "[error] Arguments are invalid."
    end
end

class Content
    def initialize()
        @err_msg = nil
        @ret_msg = nil
        @date_str = nil
        @confirmed = nil
        @deaths = nil
        @recovered = nil
        @res = nil
    end

    attr_accessor :err_msg, :ret_msg, :res, :date_str, :confirmed, :deaths, :recovered

    def update_ret(str)
        unless (@ret_msg)
            @ret_msg = ""
        end
        @ret_msg = @ret_msg + str
        return @ret_msg
    end
end

bot = Discordrb::Commands::CommandBot.new(
    token: TOKEN,
    client_id: CLIENT_ID,
    prefix:'/',
)

bot.command :covid do |event, *args|
    content = Content.new
    main_func(content, args)
    if (content.err_msg) then
        event.send_embed do |embed|
          embed.title = "Error"
          embed.colour = 0xFF1F1F
          embed.description = content.err_msg
        end
    else
        event.send_embed do |embed|
          embed.title = "Covid INFO"
          embed.colour = 0x1E90FF
          embed.description = content.ret_msg
          embed.add_field(
            name: "Date:",
            value: content.date_str,
            inline: false
          )
          embed.add_field(
            name: "Confirmed:",
            value: content.confirmed,
            inline: true
          )
          embed.add_field(
            name: "Deaths:",
            value: content.deaths,
            inline: true
          )
          embed.add_field(
            name: "Recovered:",
            value: content.recovered,
            inline: true
          )
        end
    end
end

bot.run
