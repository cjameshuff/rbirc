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

class IRC_Msg
    attr_reader :prefix, :rawmsg, :cmd, :params, :text
    def initialize(rawmsg)
#         puts rawmsg
        @rawmsg = rawmsg
        if(rawmsg[0] == ':')
            parts = rawmsg.partition(' ')
            @prefix = parts[0]
            rawmsg = parts[2]
        else
            @prefix = ''
        end
        parts = rawmsg.partition(' :')
        @params = parts[0].split(' ')
        @cmd = @params.shift
        @text = parts[2].chomp
    end
    
    def nick()
        # :Nick!Nick@blahblah.net
        @prefix.partition('!')[0][1..-1]
    end
    
    def channel()
        if(cmd == 'PRIVMSG')
            params[0]
        else
            nil
        end
    end
end

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
        if(reason != '')
            send_irc("QUIT :#{reason}")
        else
            send_irc("QUIT")
        end
        disconnect()
        exit()
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
    
    # TODO: straighten out channel-specific commands...keep "current channel"?
    # Or always specify channel?
    def send_msg(msg, channel)
        prefix = "PRIVMSG #{channel} :"
        max_len = 255 - prefix.length
        msg = msg.dup()
        while(msg.length > 0)
            send_irc(prefix + msg.slice!(0, max_len))
        end
    end
    
    def send_action_msg(msg, channel)
        # wrap each message chunk in CTCP ACTION
        # May be better to wrap only first chunk of messages long enough to need splitting.
        msg = msg[4, msg.length]# cut off '/me '
        prefix = "PRIVMSG #{channel} :"
        max_len = 255 - prefix.length - 8
        while(msg.length > 0)
            send_irc(prefix + "\001ACTION #{msg.slice!(0, max_len)}\001")
        end
    end
    
    def handle_input(src)
        handle_input_text(src.gets().chomp)
    end
    
    def handle_input_text(input)
        # TODO: /part /msg /notice /whois /whowas, others...
        if(input.start_with?('/join '))
            join(input.split(' ')[1])
        elsif(input.start_with?('/nick '))
            nick(input.split(' ')[1])
        elsif(input.start_with?('/quit'))
            quit(input.partition(' ')[1])
        elsif(input.start_with?('/me '))
            if(@current_channel)
                send_action_msg(input, @current_channel[:name])
            else
                puts "Not in any channel!"
            end
        else
            if(@current_channel)
                send_msg(input, @current_channel[:name])
            else
                puts "Not in any channel!"
            end
        end
    end
    
    #----------------------------------------------------------------
    
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
                    handle_msg(IRC_Msg.new(src.gets()))
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
        pp "<< #{msg}"
        @sock.send("#{msg}\r\n", 0)
    end
    
    def handle_msg(msg)
        sym = "rx_#{msg.cmd.downcase}".to_sym
        if(self.respond_to?(sym))
            self.send(sym, msg)
        else
            rx_unimplemented_msg(msg)
        end
    end
end # class IRC_Connection

end # module IRC
