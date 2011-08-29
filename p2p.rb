################################################################################
#                        S h o e s      P 2 P
################################################################################
# 
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
#    server(s) maintain a list of clients presents on the net
#    clients   annouce on server(s) and share files with others clients
#       * file transfert decision on (locl exist) or (time based)
#    peer ip liste ares arbitrary limited to 100 known peer
#    after a long time, files systems should be stabilised : all peer will have the sames
#      files on there share directory ...
#
# precautions:
#		too much files in list
#		too big files
#		too much client
#		too many file from one peer
#		too old files (!)
# 
# Issues
#   $container (liste of peer) and $proxy should be threaded synchronized
#   Shoes (if use) must support threading !!
#
################################################################################
VERSION=1.04

MAX_PEER_KNOWN=100				# server side : trnsmit only 100 first peer in current list
PERIOD_WATCH_PEERS_OTHERS=60	# any side 
PERIODE_GET_LIST_AND_FILE=10	# client side
TEMPO_GETDIR=60					# serveur side : scan local dir each 60 seconds (mini,on demand)
PROB_READDIR_PEER_PERCENT=30	# % : each 10secs , get distant dir if xx% lucky
PROB_WATCH_BANNED=5 			# % : a banned site is respawn at prob of 5%
MAX_SIZE_FILE=10*1000*1000		# any side : for make dir list and before memorize file
PORT_DEF=50500					# tcp port for server, +1... for clients
MAX_FILE_FROM_ONE_PEER=1000		# client side 
MAX_OLD_FILE=90*24*3600			# serveur side : do not transmit old files (?...)
MARKEUR_ANNOUNCE=/#\s*P2P_ANNOUNCE([^)]+)/  # client side, extracted from sources file for gui

$pattern="**/*{rb,png,gif,jpg,txt,md,pdf,html,js,sass,svg,ru,yml,xml}"   # serveur side for scan local dir
$patterncli=/^[\w_][\w_\s\-\/]*\.(rb)|(png)|(gif)|(jpg)|(txt)|(md)|(pdf)|(html)|(js)|(sass)|(svg)|(ru)|(yml)|(xml)$/i # client side verification before store

################################################################################
require'drb';
require 'socket'
require 'fileutils'
require 'timeout'

$container=[]
$proxy={}

module GUI_interface
  #--------------- Callback to GUI ----------------------  
  # p2p is run by > Objetct.run_p2p(shoes,pass,mode,lserver) by 'parent'
  # then this callback is called by p2p to parent
  
  def sending(f)			end
  def receiving(f,client)	end
  def suspended?()			end
  def discover(client)		end
  def forget(client)		end
  def update_nbfile(n)		end
  def log(*txt)
	puts("%-8s | %29s | %-3s | %s" % [Time.now.strftime("%H:%M:%S"),DRb.uri,self.class.to_s[0..3],txt.join(' ')]) unless txt[0][0,1]==" "
  end
end

module Common
  include GUI_interface
  def fbasename(p) p.gsub(/^\//,"blurp").gsub('..',"bleurp")	end
  def mkdir(d)     FileUtils.mkdir_p(d) 						end
  def proxy(u)     $proxy[u] || ( $proxy[u]=DRbObject.new((),u)) end
  def sign(data)   [$Password,data].join('/') 					end # !!! TODO sha?
  def tr(*txt)    log('TRACE: '+txt.map {|a| a.inspect}.join(", ")[0..100]) if *DEBUG ; txt[0] end
  
end

class Serveur
  include Common
  def eval(*a) raise('') end
  def instance_eval(*a) raise('') end
  def fserver(c,param,action) 
  tr [c,action,"   ",param]
  begin
	if c==sign("")
	  case action 
	 	when :getdir     
	 	  tr $Mode=="client" ? getdir(param) : nil 
	 	when :getfile    
	 	   sending(param)
		   log "Sending #{param}"
		   File.read( fbasename(param) ) 
	 	when :getmembers 
	 	 tr add_peers(false,param)[0..MAX_PEER_KNOWN]
	 	when :geturi 
	 	 [DRb.uri]
	 	when :test
			"ok"
	 	when :discover
			 ok_drb(param) ? (discover(param.to_s);add_peers(true,[param])[0..MAX_PEER_KNOWN] ): false
	 	else
	 	 log "unknwon request #{action.inspect}"
	 	 []
	  end
	else
	  log "error password?"
	  nil
	end
  rescue
	log $!.to_s+ " "+ $!.backtrace[0..2].join(" < ")
  end
  end
  def getdir(filter)
	now=Time.now
	if (! defined?(@last_dir_time)) || (@last_dir_time[0]+TEMPO_GETDIR) < now
	  # list files good size and not too old
	  list=Dir[filter].select { |f|  
		File.size(f) <= MAX_SIZE_FILE && (File.mtime(f)+MAX_OLD_FILE) > now
	  }.map { |file| [ file,File.mtime(file).to_i ] }
	  
	  # send only most recent (if file list is too big)
	  list=list.sort {|a,b| b[1]<=>a[1] }[0..2*MAX_FILE_FROM_ONE_PEER]
	  @last_dir_time=[Time.now+(Time.now-now)*10,list]
	  update_nbfile(list.size)
	  list
	else
	  @last_dir_time[1]
	end
  end
  def init(is_server)
	Thread.new {
	
	  add_peers( true , [ DRb.uri ])      
	  first_discover_other_peer(is_server)
	  log "I am #{DRb.uri}, create Client part..."
	  Client.new().run unless is_server

	  ############### watch presence of known peer and get there known peer list
	  loop {
		sleep PERIOD_WATCH_PEERS_OTHERS
		timeout(200) { whatch_presence_peers(is_server) } rescue tr($!,*$!.backtrace)
	  }
	}
   end
   private
  def first_discover_other_peer(is_server)
	  loop {
		log "finding almost one server..."
		$servers[(is_server ? 1:0)..-1].each do |serv|
			begin
			  l=proxy(serv).fserver( sign(""),DRb.uri,:discover ) 
			  l ? add_peers( true , l ) : log("*** Issue firewall /NAT ? ***")
			rescue
			end
		end
		break if $container.size>1
		break if is_server
		sleep 10
	  } 
	  if $container.size<=1
		log "I am alone as server"
	  else
		log "#{$container.size-1} Server(s) is discovered"
	  end
  end

  def whatch_presence_peers(is_server)
	lcont=$container.dup
	lerr=[]
	lcont.each { |n| 
	  next if n.to_s==DRb.uri.to_s
	  next if n.to_s==$servers[0]
	  begin
		tr "Check #{n}..."
		add_peers(false,proxy(n).fserver( sign(""),$container,:getmembers ))
	  rescue
		lerr << n
	  end
	}  
	if lerr.size>0 && (lcont.size-lerr.size) > 4
	   lerr.each {|e| log "Discard #{e}" }
	   $container=lcont - lerr 
	end
  end

  def add_peers(nocheck=false,peers0=[])
	return($container) unless peers0
	Thread.new(peers0) { |peers|
		l=peers.flatten.select{ |elem| (! $container.index(elem) ) && ( nocheck || ok_drb(elem)) } 
		if l.size>0
		  l.each {|elem| log "Discovered #{elem}" ; discover(elem.to_s) }
		  $container=$container.push(*(peers.flatten)).uniq
		end
	} if peers0.size>0
	$container
  end  

  def ok_drb(uri)
	tr "Test access #{uri}..."
	timeout(7) { proxy(uri).fserver( sign(""),"",:test) }
	true
  rescue Exception => e
	log "Unreachable  #{uri} ! : " + e.to_s
	false
  end
end

###################################### Client ##########################################

class Client
  include Common
  def initialize()
	@iam=proxy(DRb.uri).fserver( sign(""),[],:geturi)[0]
	log "I am #{@iam}"
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

	 	@ban.delete(n)
	 	#log "Consult #{n}... "
	 	directory_transfert(n) unless suspended?()
		rescue
			log "peer #{n} seem to be down"
			log "     "+$!.to_s+ " "+ $!.backtrace[0..1].join(" < ")
		end ; end
		sleep PERIODE_GET_LIST_AND_FILE
	  }
	end
  end
  def directory_transfert(n)
	l=proxy(n).fserver(sign(""),$pattern,:getdir)
	return if !l
	filelist=l.map { |f,t| [fbasename(f),t] } 
	filelist.each do |f,time|
	  if f !~ $patterncli
		log "File name has strange type : #{f}, banning #{n}"
		@ban[n]=Time.now
		return
	  end
	end
	nbfiles=0
	filelist.each do |f,time|
	  (@ban[n]=Time.now;break) if nbfiles>MAX_FILE_FROM_ONE_PEER
	  if !  suspended?() && ( (! File.exists?(f)) || File.mtime(f).to_i<time )
		nbfiles+=1
		receiving(f,n.to_s)
		content= proxy(n).fserver(sign(""),f,:getfile)
		if  content.size > MAX_SIZE_FILE 
			log "received file #{f} too big: #{content.size/1024} KB from #{n}"
			content="#file too big for S2S : original size=#{content.size} B !"
		end
		dir=File.dirname(f)
		(log "create dir #{dir}" ; mkdir(dir)) unless File.directory?(dir)
		if (! File.exists?(f)) || File.mtime(f).to_i<time
			log "gets #{f}          from #{n}" 
			File.open(f,"w") {|o| o.print(content) }    
			t=Time.at(time)
			File.utime(t,t,f)
			log("from #{f} : #{$1}")  if content.match(MARKEUR_ANNOUNCE) && $1!~/\[/
		end
	  end
	end
  rescue Exception => e
	tr "     "+$!.to_s+ " "+ $!.backtrace[0..1].join(" < ")
  end
end

def get_public_ip()
  UDPSocket.open do |s|
	s.connect '208.80.152.2', 1 # wikipedia, connection don't need effective
	s.addr.last
  end
end



def run_p2p(pass,mode,lserver)
  $Password=pass
  $Mode=mode        # type: client/server
  $servers=lserver  # serveur
  
  Socket.do_not_reverse_lookup=true
  serv=Serveur.new() # everybody is server
  if $Mode=="client"
	9.times { |i| (DRb.start_service( "druby://#{get_public_ip()}:#{PORT_DEF+1+i}" ,serv);break) rescue nil ; puts "retry #{get_public_ip()}" }
	serv.init(false)   
  else
	DRb.start_service( $servers[0] ,serv) # only servers have fixed ip
	serv.init(true)   
  end
end

if __FILE__==$0 
  if ARGV.size==0
	ARGV << "shoerdev"
	ARGV << "client"
	ARGV << "druby://homeregis.dyndns.org:50500"
  end
  password=ARGV.shift  # password :)
  mode=    ARGV.shift  # type: client/server
  servers=ARGV        # serveur

  Thread.abort_on_exception=true
  run_p2p(password,mode,servers)
  sleep
else
 puts "p2p.rb loaded!"
end