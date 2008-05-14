# KayakSearch

require 'net/http'
require 'rexml/document' 
require 'uri'

module TwoAndOut
    module KayakSearch
        API_SERVER = 'api.kayak.com'
        API_PORT = '80'

        class KayakSearch
            attr :sid, true
            attr :origin, true
            attr :destination, true
            attr :depart_date, true
            attr :return_dat, true

            def get_session
                if ENV['KAYAK_TEST'] == 'true'
                    return 'DUMMY_KAYAK_SID'
                end
                Net::HTTP.start(API_SERVER, API_PORT) do |http|
                    response = http.get("/k/ident/apisession?token=#{ENV['KAYAK_API_KEY']}")
                    body = response.body
                    xml = REXML::Document.new(body)
                    @sid = xml.elements['//sid'].text
                end
                return @sid
            end

            def start_flight_search(options = {})
                options.assert_valid_keys :sid, :depart_date, :return_date, :origin, :destination, :oneway, :depart_time, :return_time, :travellers, :cabin
                options.reverse_merge!  :sid => @sid, :depart_date => @depart_date, :return_date => @return_date, :origin => @origin, :destination => @destination, :oneway => 'n', :depart_time => 'a', :return_time => 'a', :travellers => 1, :cabin => 'e'

                url = "/s/apisearch?basicmode=true&oneway=n&origin=#{options[:origin]}&destination=#{options[:destination]}&destcode=&depart_date=#{format_date options[:depart_date]}&depart_time=#{options[:depart_time]}&return_date=#{format_date options[:return_date]}&return_time=#{options[:return_time]}&travelers=#{options[:travellers]}&cabin=#{options[:cabin]}&action=doflights&apimode=1&_sid_=#{options[:sid]}"
                return start_search(url)
            end

            def start_hotel_search(options = {})
                options.assert_valid_keys :sid, :city, :state, :country, :depart_date, :return_date, :rooms, :travellers
                options.reverse_merge!  :sid => @sid, :depart_date => @depart_date, :return_date => @return_date, :origin => @origin, :destination => @destination, :oneway => 'n', :depart_time => 'a', :return_time => 'a', :travellers => 1, :cabin => 'e'

                csc = URI.escape(options[:citystatecountry])
                options[:dep_date] = URI.escape(options[:dep_date])
                options[:ret_date] = URI.escape(options[:ret_date])
                url = "/s/apisearch?basicmode=true&othercity=#{options[:csc]}&checkin_date=#{options[:dep_date]}&checkout_date=#{options[:ret_date]}&minstars=-1&guests1=#{options[:travelers]}&guests2=1&rooms=1&action=dohotels&apimode=1&_sid_=#{options[:sid]}"
                return start_search(url)
            end

            def poll_results(options = {})
                options.assert_valid_keys :sid, :search_id, :search_type, :count, :max_count
                options.reverse_merge!  :sid => @sid, :search_type => 'f', :max_count => 99999

                if ENV['KAYAK_TEST'] == 'true'
                    xml = REXML::Document.new(File.open(ENV['KAYAK_TEST_FILE'],"r").read)
                    return xml
                end

                url = 
                    case 
                    when options[:search_type] == 'f': "/s/apibasic/flight?searchid=#{options[:search_id]}&apimode=1&_sid_=#{sid}"
                    when options[:search_type] == 'h': "/s/apibasic/hotel?searchid=#{options[:search_id]}&apimode=1&_sid_=#{sid}"
                    end

                Net::HTTP.start(API_SERVER, API_PORT) do |http|
                    if options[:count]
                        url += "&c=#{options[:count]}"
                    end
                    response = http.get(url)
                    body = response.body
                    xml = REXML::Document.new(body)
                    more = xml.elements['/searchresult/morepending'].text
                    count = xml.elements['/searchresult/count'].text.to_i
                    if more == 'true' && count < options[:max_count]
                        return true, xml
                    else
                        # We make one final API call to collect all of the results
                        if options[:max_count] && count > options[:max_count]
                            count = options[:max_count]
                        end
                        url += "&c=#{count}"
                        xml = REXML::Document.new(http.get(url).body)
                        # Saving files in development
                        if ENV['RAILS_ENV'] == 'development'
                            File.open("#{RAILS_ROOT}/tmp/kayak_search/"+rand(10000).to_s+".xml","w") do |f|
                            f.puts(body)
                            end
                        end
                        return false, xml
                    end
                end
                return false, xml
            end

            private
            def start_search(url)
                if ENV['KAYAK_TEST'] == 'true'
                    return 'DUMMY_KAYAK_SEARCHID'
                end
                searchid = nil
                Net::HTTP.start(API_SERVER, API_PORT) do |http|
                    response = http.get(url)
                    body = response.body
                    xml = REXML::Document.new(body)
                    searchid = xml.elements['//searchid']
                    if searchid 
                        searchid = searchid.text
                    else
                        return nil
                    end
                end
                return searchid
            end

            def format_date(date)
                if Date===date
                    date.strftime("%m-%d-%Y")
                else
                    Date.parse(date).strftime("%m-%d-%Y")
                end
            end

        end

    end
end
