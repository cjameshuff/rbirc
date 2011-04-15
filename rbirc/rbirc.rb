#*******************************************************************************
#    Copyright (c) 2011, Christopher James Huff
#    All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#*******************************************************************************

require 'pp'
require 'socket'
require 'rbirc/handlers'

module IRC

DEFAULT_IRC_OPTS = {
    hostname: 'localhost',
    servername: 'localhost',
    shortusername: 'shortusername',
    realusername: 'Long User Name',
    usermode: 0,
    auto_reconnect_time: 30.0,# seconds
    poll_timeout_time: 1.0,# seconds
    ping_timeout_time: 90.0,# seconds, also used as ping interval
    select_sources: [$stdin]
}

CTCP = '\001'

class IRC_Connection
    attr_reader :options, :connections, :connected, :lag
    attr_reader :channels, :nick
    attr_accessor :current_channel
    attr_reader :server_info, :server_notices, :server_motd
    
    def initialize(server, port, options = {})
        @time_disconnected = Time.now
        @connected = false
        @server = server
        @port = port
        @nick = ""
        
        @server_info = []
        @server_notices = []
        @server_motd = []
        
        @channels = {}
        @current_channel = nil
        
        @options = DEFAULT_IRC_OPTS.merge(options)
        
        @ping_start = 0
        @lag = 0
        @waiting_for_pong = false
    end
    
    def update_lag(new_lag)
        @lag = new_lag
        puts "Lag: #{@lag}"
    end
    
    #----------------------------------------------------------------
    # IRC commands
    #----------------------------------------------------------------
    def connect()
        @sock = TCPSocket.open(@server, @port)
        # RFC 1459 version:
        send_irc("USER #{@options[:shortusername]} #{@options[:hostname]} " +
            "#{@options[:servername]} :#{@options[:realusername]}")
        # RFC 2812 version:
#        send_irc("USER #{@options[:shortusername]} #{@options[:usermode]} * :#{@options[:realusername]}")
    end
    
    def disconnect()
        @connected = false
        @sock.close()
        @sock = nil
        @time_disconnected = Time.now
    end
    
    def quit(reason = '')
        send_irc("QUIT #{reason}")
        disconnect()
    end
    
    def nick(nickname)
        @nick = nickname
        send_irc("NICK #{@nick}")
    end
    
    def ping()
        @ping_start = Time.now.to_f
        @waiting_for_pong = true
        send_irc("PING :#{@ping_start}")
    end
    
    def join(channel)
        send_irc("JOIN #{channel}")
        @channels[channel] = {
            name: channel,
            topic: "",
            users: []
        }
        @current_channel = @channels[channel]
    end
    
    def send_msg(msg, channel)
        prefix = "PRIVMSG #{channel} :"
        max_len = 255 - prefix.length
       while(msg.length > 0)
            send_irc(prefix + msg.slice!(0, max_len))
       end
    end
    
    def handle_input(src)
        input = src.gets()
        if(@current_channel)
            send_msg(input, @current_channel[:name])
        else
            puts "Not in any channel!"
        end
    end
    
    #----------------------------------------------------------------
    
    def get_nick(msg)
        # :Nick!Nick@blahblah.net
        nick = msg[:prefix].partition('!')[0][1..-1]
    end
    
    def poll()
        if(@sock == nil && @options[:auto_reconnect_time] != nil &&
           (Time.now - @time_disconnected).to_f > @options[:auto_reconnect_time])
            puts "Attempting automatic reconnect..."
            connect()
        end
        
        if(@sock == nil)
            # select anyway, to allow instructions to be handled while not connected
            sel = select(@options[:select_sources], nil, nil, @options[:poll_timeout_time])
        else
            sel = select(@options[:select_sources] + [@sock], nil, nil, @options[:poll_timeout_time])
        end
        
        if(sel != nil)
            for src in sel[0]
                if(src == @sock)
                    handle_rawmsg(src)
                else
                    handle_input(src)
                end
            end # for src in sel[0]
        end # (sel != nil)
        
        if(@connected && (Time.now.to_f - @ping_start) > @options[:ping_timeout_time])
            if(@waiting_for_pong)
                # Ping timeout
                puts "Disconnected by ping timeout!"
                disconnect()
                
                # assume disconnect had occurred at time of last ping, and correct
                # the disconnect time to avoid overly long reconnect interval.
                if(@options[:ping_timeout_time] != nil)
                    @time_disconnected -= @options[:ping_timeout_time]
                end
            else
                ping()
            end
        end
    end # poll()
    
    def send_irc(msg)
        puts "<< #{msg}"
        @sock.send("#{msg}\r\n", 0)
    end
    
    # Parses a raw IRC message string and hands it off to handle_msg().
    # Parsed message format:
    # {
    #     rawmsg: "raw message text",
    #     prefix: ":Nick!Nick@blahblah.net JOIN :#SomeChannel",
    #     cmd: "IRC_COMMAND",
    #     params: [...],
    #     text: "last param"
    # }
    def handle_rawmsg(rawmsg)
        if(@sock.eof?)
            puts "Disconnected!"
            disconnect()
            return
        end
        
        rawmsg = @sock.gets
#         puts rawmsg
        msg = {rawmsg: rawmsg}
        if(rawmsg[0] == ':')
            parts = rawmsg.partition(' ')
            msg[:prefix] = parts[0]
            rawmsg = parts[2]
        end
        parts = rawmsg.partition(' :')
        msg[:params] = parts[0].split(' ')
        msg[:cmd] = msg[:params].shift
        msg[:text] = parts[2].chomp
        
        handle_msg(msg)
    end
    
    def handle_msg(msg)
        sym = "rx_#{msg[:cmd].downcase}".to_sym
        if(self.respond_to?(sym))
            self.send(sym, msg)
        else
            rx_unimplemented_msg(msg)
        end
    end
end # class IRC_Connection

end # module IRC
