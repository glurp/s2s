################################################################################
#                        S h o e s      P 2 P
################################################################################
# 2 types of member:
#     serveur : give only adresses of all member which had connect  to him
#     client  : take list of member from one or several serveur, 
#               echange files with others known clients
#               clients are server too
#
# so server(s) are necessary only at startup of a client.
# One server : homeregis.dyndns.com:50500 / password "shoerdev"
#
# Server> ruby p2p.rb password server server-uri1  server-uri2 server-uri3 ...
# Client> ruby p2p.rb password client server-uri server-uri2
#
#Exemple:
# server> ruby p2p.rb shoerdev server druby://192.168.0.1:50500
# client> ruby p2p.rb shoerdev client druby://homeregis.dyndns.com:50500  druby://192.168.0.1:50500  
#
#---------------------------------------------------------------------------------
#   original form
#---------------------------------------------------------------------------------
#
# require'drb';
# F,    D    ,C    ,P,M,U,*O=
# File,Class,Dir,*ARGV;def s(p)F.split(p[/[^|].*/])[-1
# ]end;def c(u);DRbObject.new((),u)end;def x(u)[P,u].hash;end;M=="client"&&c(U).f(
# x(U)).each{|n|p,c=x(n),c(n);(c.f(p,O[0],0).map{|f|s f}-D["*"]).each{|f|F.open(f,
# "w"){|o|o<<c.f(p,f,1)}}}||(DRb.start_service U,C.new{def f(c,a=[],t=2)c==x(U)&&(
# t==0&&D[s(a)]||t==1&&F.read(s(a))||p(a))end;def y()(p(U)+p).each{|u|c(u).f(x(u),
# p(U))rescue()};self;end;private;def p(x=[]);O.push(*x).uniq!;O;end}.new.y;sleep) 
#
#---------------------------------------------------------------------------------
# Principes
#    server(s) maintain tje liste of clients presents on the net
#    clients   annouce on server(s) and share files with others clients
#       * a file is copied if it existe on one client and not on my host
#        (transfert decision is only on filename existence, no (not yet) mtime check
#    peer ip liste ares arbitrary limited to 50 known peer
#    after a long time, files systems should be stabilised : all peer will have the sames
#      files on there share directory ...
#
# Issues
#   $container (liste of peer) and $proxy should be threaded synchronized
#   make a dir cache?
#   Shoes (if use) must support threading !!
#
################################################################################

MAX_PEER_KNOWN=100
PERIOD_WATCH_PEERS_OTHERS=60
PERIODE_GET_LIST_AND_FILE=10
PROB_READDIR_PEER_PERCENT=30	# % : each 10secs , get distant dir if xx% lucky
PROB_WATCH_BANNED=5 			# % : a banned site is respawn at prob of 5%
MAX_SIZE_FILE=10*1000
PORT_DEF=50500

$pattern="**/*{rb,bng,gif,jpg,txt,md}"   # serveur side for Dir[$pattern]
$patterncli=/^[\w_][\w_\s\-\/]*\.(rb)|(png)|(gif)|(jpg)|(txt)|(md)$/i # client side verification before store

################################################################################
require'drb';
require 'fileutils'
require 'timeout'

$container=[]
$proxy={}

module P2P_shoes
  def fbasename(p) p.gsub(/^\//,"blurp").gsub('..',"bleurp")  end
  def mkdir(d)     FileUtils.mkdir_p(d) end
  def proxy(u)     $proxy[u] || ( $proxy[u]=DRbObject.new((),u)) 		 	end
  def sign(data)   [$Password,data].join('/') 									end # !!! TODO sha?
  def shoes?()     defined?(Shoes) && Shoes.app.respond_to?(:s2s_notify) && Shoes.app	end 
  def sending(f,client)		shoes?() && shoes?().s2s_notify(:sending,f,client)	end
  def receiving(f,client)	shoes?() && shoes?().s2s_notify(:receiving,f,client) end
  def suspended?()			shoes?() && shoes?().is_suspended?()				end
  def discover(client)		shoes?() && shoes?().s2s_notify(:discover,f,client) end
  def forget(client)		shoes?() && shoes?().s2s_notify(:forget,"",client)end
  def log(*txt)
    puts("%-8s | %29s | %-3s | %s" % [Time.now.strftime("%H:%M:%S"),DRb.uri,self.class.to_s[0..3],txt.join(' ')]) unless txt[0][0,1]==" "
  end
  def t(*txt)    log(txt.map {|a| a.inspect}.join(", ")[0..100]) end
end

class Serveur
  include P2P_shoes
  def fserver(c,param,action) 
  t [c,action,"   ",param]
  begin
    if c==sign("")
      case action 
         when :getdir     
           (log(" Send dir #{param}...") ; $Mode=="client" ? getdir(param) : nil )
         when :getfile    
           (log("Send file #{param}..."); File.read( fbasename(param) ) )
         when :getmembers 
          add_peers(param)[0..MAX_PEER_KNOWN]
         when :geturi 
          [DRb.uri]
         when :test
			"ok"
         else
          log "unknwon request #{action.inspect}"
          []
      end
    else
      log "request not for me!"
      add_peers()
    end
  rescue
    log $!.to_s+ " "+ $!.backtrace[0..2].join(" < ")
  end
  end
  def getdir(filter)
	Dir[filter].map { |f|  [ f , File.mtime(f).to_i ] }
  end
  def init(is_server)
    Thread.new {
    
      add_peers([ DRb.uri ])      
      first_discover_other_peer(is_server)
      
      ############### watch presence of known peer and get there known peer list
      loop {
        sleep PERIOD_WATCH_PEERS_OTHERS
        whatch_presence_peers(is_server)
      }
    }
   end
   private
  def first_discover_other_peer(is_server)
      loop {
        $servers[(is_server ? 1:0)..-1].each do |serv|
          add_peers( proxy(serv).fserver( sign(""),[DRb.uri],:getmembers )  ) rescue p $!
        end
        break if $container.size>1
        break if is_server
        sleep 10
        log "finding almost one server..."
      } 
      log "#{$container.size-1} Server(s) is discovered"
  end

  def whatch_presence_peers(is_server)
    lcont=$container
    touched = false
	(log "Mute" ; $container << DRb.uri) unless $container.index(DRb.uri) # self uri can change
    lcont.dup.flatten.each { |n| 
      next if n==DRb.uri
      begin
        add_peers(proxy(n).fserver( sign(""),$container,:getmembers ))
      rescue
        log "Discard #{n}"
        log $!.to_s+ " "+  $!.backtrace[0..2].join(" < ")
        lcont.delete(n)
        touched = true
      end
    }  
    $container=lcont if touched && lcont.size>0
  end

  def add_peers(peers0=[])
    return($container) unless peers0
	Thread.new(peers0) { |peers|
		l=peers.flatten.select{ |elem| (! $container.index(elem) ) && ok_drb(elem) } 
		if l.size>0
		  l.each {|elem| log "Discovered #{elem}" }
		  $container=$container.push(*(peers.flatten)).uniq
		end
	} if peers0.size>0
    $container
  end  

  def ok_drb(uri)
	log "Test accesiblility #{uri}..."
    timeout(5) { proxy(uri).fserver( sign(""),"",:test) }
	true
  rescue Exception => e
	t e,e.backtrace
	false
  end
end

class Client
  include P2P_shoes
  def initialize()
    @iam=proxy(DRb.uri).fserver( sign(""),[],:geturi)[0]
    log "I am #{@iam}"
	@hserv={}
    @ban={}
  end
  def run
    Thread.new do
      loop {
        first=true
        $container.dup.each do |n|
        begin
         next if n==DRb.uri || n==@iam
         next if @ban[n] && rand(100)>PROB_WATCH_BANNED
         next if rand(100)>PROB_READDIR_PEER_PERCENT
		 next if @hserv[n]

         @ban.delete(n)
         #log "Consult #{n}... "
         directory_transfert(n)
        rescue
			log "peer #{n} seem to be down"
			log "     "+$!.to_s+ " "+ $!.backtrace[0..1].join(" < ")
			$container.delete(n) #  !!!
        end ; end
        sleep PERIODE_GET_LIST_AND_FILE
      }
    end
  end
  def directory_transfert(n)
    l=proxy(n).fserver(sign(""),$pattern,:getdir)
	if !l
		@hserv[n]=1
		return
	end
    filelist=l.map { |f,t| [fbasename(f),t] } 
    filelist.each do |f,time|
	  if f !~ $patterncli
		log "File name has strange type : #{f}, banning #{n}"
		#@ban[n]=1
		return
	  end
    end
    filelist.each do |f,time|
      if (! File.exists?(f)) || File.mtime(f).to_i<time
        content= proxy(n).fserver(sign(""),f,:getfile)
        if  content.size > MAX_SIZE_FILE 
			log "received file #{f} too big: #{content.size/1024} KB from #{n}"
			content="#file too big for S2S"
		end
		dir=File.dirname(f)
		(log "create dir #{dir}" ; mkdir(dir)) unless File.directory?(dir)
        log "gets #{f}          from #{n}" 
		File.open(f,"w") {|o| o.print(content) }    
        t=Time.at(time)
		File.utime(t,t,f)
      end
    end
  rescue Exception => e
	t "     "+$!.to_s+ " "+ $!.backtrace[0..1].join(" < ")
  end
end

$Password=""
$Mode=""

def run_p2p(shoes,pass,mode,lserver)
  $Password=pass
  $Mode=mode        # type: client/server
  $servers=lserver  # serveur

  serv=Serveur.new() # everybody is server
  if $Mode=="client"
		9.times { |i| (DRb.start_service( "druby://:#{PORT_DEF+1+i}" ,serv);break) rescue nil  }
		serv.init(false)   
		Client.new().run
  else
		DRb.start_service( $servers[0] ,serv) # only servers have fixed ip
		serv.init(true)   
  end
end

if __FILE__==$0 
  Thread.abort_on_exception=true
  if ARGV.size==0
	ARGV << "shoerdev"
	ARGV << "client"
	ARGV << "druby://homeregis.dyndns.org:50500"
  end
  password=ARGV.shift  # password :)
  mode=    ARGV.shift  # type: client/server
  servers=ARGV        # serveur

  run_p2p(nil,password,mode,servers)
  sleep
end