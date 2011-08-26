require 'green_shoes'
require 'fileutils'
require 'thread'
#require './p2p.rb'

###########################  Patch fg() bg() for permission to use string color
class Shoes
  class App
    [[:bg, :background], [:fg, :foreground]].each do |m, tag|
      define_method m do |*str|
        color = str.pop
        str = str.join
		unless String===color # <<<
			rgb = "#"+(color[0, 3].map{|e| (e*255.0).to_i}.map{|i| sprintf("%#02X", i)[-2,2]}.join)
		else
			rgb=color # <<<
		end
        "<span #{tag}='#{rgb}'>#{str}</span>"
      end
    end
  end
end

######################" Patch ChipMunk : destroy a shape....

#---------- append shap to attribute
begin
ChipMunk # load file (ext are autoloaded by greeen shoes)
module ChipMunk
  def spy
	p @space.methods - Object.methods
  end

  def cp_oval l, t, r, opts = {}
    b = CP::Body.new 1,1
    b.p = vec2 l, t
    @space.add_body b
	shape=CP::Shape::Circle.new(b, r, vec2(0, 0))
    @space.add_shape shape
      
    opts = opts.merge({left: l-r-1, top: t-r-1, width: 2*r+2, height: 2*r+2, body: b, inflate: r-2, shape: shape})
    oval opts
  end
end
#----------  create methode cp_remove, which destroy in shoes AND in ChipMunk 

Shoes::ShapeBase.class_eval do
  def cp_remove(space)
    space.remove_body( args[:body])
    space.remove_shape( args[:shape])
	self.remove
  end
end
##################### END patchs chipmunk/green shoes

####################### Physique space : a shape is a file which arrive by p2p


class Blackboard  < Shoes::Widget
  include ChipMunk
  def initialize( is_simulation = true)
	  @nbfile_pop=0
	  @nbfile_push=2
	  @ip={}
	  space = cp_space
	  balls = []
	  nofill
	  cp_line 0, 180, 200, 280,   stroke: "#806060"
	  cp_line 200, 280, 300, 270, stroke: "#806060"
	  cp_line 250, 450, 300, 452, stroke: "#806060"
	  cp_line 300, 452, 500, 454, stroke: "#806060"


      #------- border drawing area

	  cp_line 0,100, 0,484 ,      stroke: "#204040"
	  cp_line 600,484, 600,100,   stroke: "#204040"
	  cp_line 0,480 ,600,480,    stroke: "#205050" ,strokewidth: 2
	  
	  line 0,484 ,600,484,    stroke: "#A0E0E0",strokewidth: 2
	  line    0,100 ,600,100,    stroke: "#A0E0E0",strokewidth: 1
	  
	  d=24
	  cp_oval 100,d+450, 60,        fill: "#E3EB70" ,  stroke: "#EBEB70"
	  line    0,d+480,200,d+480,      stroke: "#E0E0E0" ,strokewidth: 40

	  nostroke
	  
	  if is_simulation
		  100.times { balls <<  [0,drop_ball() ] } 
		  animate(3) do
				balls <<  [0,drop_ball() ] while balls.size<150 if (balls.size<70)
				bloc_on("#{200+(Time.now.to_f*10).round%100}")
				bloc_off("#{200+(Time.now.to_f*10+1).round%100}")
		  end
	  end
	  animate(7) do
		while @nbfile_push>0 && balls.size < 150
			balls << [0,drop_ball() ] 
			@nbfile_push -= 1
		end
		while @nbfile_pop>0 && balls.size > 0
			@nbfile_pop -= 1
		end
		unless $statusb.is_suspend
			10.times { space.step 0.05 }
			r=[]
			balls.each do |generation,ball|  
				ball.cp_move
				if generation>100 && ball.top>468 
					ball.cp_remove(space)  
				else
					r << [generation+1,ball]
				end
			end
			balls=r
			#p [r.size,r[0][0],r[0][1].top,$statusb.nbfiles]  rescue nil
			$statusb.nbfiles=balls.size if is_simulation 
			r=nil
		end
	  end
  end
  def drop_ball
	  x0,y0=110,50
	  color= rgb((50+((rand(100)<10) ? rand(200) : rand(30))).to_i ,100+rand(140),200+rand(40)) 
      cp_oval(x0+rand(30), y0+rand(40), 2+rand(4), { fill: color })
  end
  def bloc_on(ip,&blk)
	(@ip[ip].style fill: "#BB3030";return) if @ip[ip]
	col=@ip.size/25
	lig=@ip.size%25
	x=580-21*col; y=101+10*lig
	@ip[ip]=rect x,y,20,9, fill: "#BB3030"
	t=Time.now
	if blk
	  @ip[ip].click { blk.call }
	else
	  @ip[ip].click { alert("Apparition of #{ip} at #{t}") }
	end
  end
  def bloc_off(ip)
	return unless @ip[ip]
	@ip[ip].style fill: "#606060" 
	#@ip.delete(ip) # delete in hash
  end
  
  #--------------- from call back p2p
  def upload(f)			@nbfile_pop +=1	end
  def download(f)		@nbfile_push+=1	end  
  def declare(type,client)	type ? bloc_on(client) : bloc_off(client)  end  
end

################### if Chipmunk not dispo : a pannel ############## 

rescue Exception  => e
	puts " |   "+e.to_s + "\n  "+ e.backtrace.join("\n |     ")
	 ############## no chipmunk 
	class Blackboard  < Shoes::Widget
	  def initialize()
		stack margin: 50, left: -1, top: -1 do
			title
			@a=para fg(<<EEND,"#DDCC88")
If you have ChipMunk (2D space engine physique simulator) 
thank you to put 'chipmunk.so' library  in green-shoes dev project !
But S2S can work without it :)
EEND
			timer(10) { @a.text=""}
		end
	  end
	  #--------------- from call back p2p
	  def upload(f)		end
	  def download(f)	end  
	  def declare(type,client)	  end  
	end
end

####################################################################
#                       P2P inteface
####################################################################
require File.dirname(__FILE__)+"/p2p.rb"

module GUI_interface
  #--------------- Callback to GUI ----------------------  
  # p2p is run by > Objetct.run_p2p(shoes,pass,mode,lserver) by 'parent'
  # then this callback is called by p2p to parent
  
  def shoes?() Shoes.app	end 
  def sending(f)  			$app.p2p_sending(f)			end
  def receiving(f,client)	$app.p2p_receiving(f,client) end
  def suspended?()			$app.p2p_is_suspended?()	end
  def discover(client)		$app.p2P_discover(client)	end
  def forget(client)		$app.p2p_forget(client)		end
  def update_nbfile(n)		$app.p2p_update_nbfile(n)	end
  def log(*txt)
    puts("%-8s | %29s | %-3s | %s" % [Time.now.strftime("%H:%M:%S"),DRb.uri.to_s.split('//')[1],self.class.to_s[0..3],txt.join(' ')]) unless txt[0][0,1]==" "
  end
end

Thread.new {
  sleep 3
  if ARGV.size==0
	ARGV << "shoerdev"
	ARGV << "client"
	ARGV << "druby://homeregis.dyndns.org:50500"
  end
  password=ARGV.shift  # password :)
  mode="client"      # type: client/server
  servers=ARGV        # serveur

  Thread.abort_on_exception=true
  run_p2p(password,mode,servers)
}
server=ARGV.size==0 ?  "homeregis.dyndnd.org" : ARGV[1]
####################################################################
#                       Main window 
####################################################################

class MyButton < Shoes::Widget
  def initialize(left,top,text)
	r = rect       left,          top,      120,25,  fill: "#607070".."#80A0A0", strokewidth: 1, curve: 10, stroke: black
	p= para  text, left: left+10, top: top+4      ,  stroke: "#E0E0E0"

	style(width: 140, height: 80)
	style(left: left, top: top, width: 140, height: 80)
	r.click do
		r.style(fill: "#B06060".."#C06060")
		p.style stroke: "#D0D0D0"
		timer(0.1) { r.style(fill: "#607070".."#80A0A0")  } 
		yield 
	end
  end
end

class StatusBarr < Shoes::Widget
	attr_reader :nbfiles,:nbpeer,:is_suspend
	def initialize(y0)
		$statusb=self
		@nbfiles=0
		@nbpeer=0
		@is_suspend=false
		background "#506060"
		flow width: 600, height: 20, fill: "#E0E0E0" do
			background "#E0E0E0"
			inscription "    Nb Files :  "   ,stroke: "#E0E0E0" , width: 100 ,fill: "#909090"
			@nbf=inscription   '0' 		     ,stroke: "#909090" , width: 50  ,fill: "#E0E0E0"
			inscription "    Nb Shoers : "   ,stroke: "#E0E0E0" , width: 100,fill: "#909090"
			@nbp=inscription '0'             ,stroke: "#000000" , width: 50
			inscription "    State :  "      ,stroke: "#E0E0E0" , width: 100,fill: "#909090"
			@iss=inscription 'ONLINE'        ,stroke: "#000000" , width: 100
			inscription '_________________'   ,stroke: "#909090" , width: 100,fill: "#909090"
		end
    end
	def nbfiles=(v)
		sv=v.to_s
		@nbf.text= bg(fg(sv, "#909090"),"#E0E0E0") if sv!=@nbfiles
		@nbfiles=v
	end
	def nbpeer=(v)
		@nbp.text=v.to_s  if v.to_s!=@nbpeer
		@nbpeer=v
	end
	def is_suspend=(v)
		@iss.text=v ?  "OFFLINE" : "ONLINE" if v!=is_suspend
		@is_suspend=v
	end
	def view(file)
		
	end
end

class Shoes::App
  def p2p_sending(f)			invoke_in_shoes_mainloop { @bl.upload(f) }				end
  def p2p_receiving(f,client) 	invoke_in_shoes_mainloop { @bl.download(f)	; $statusb.nbfiles+=1 }			end  
  def p2P_discover(client) 	invoke_in_shoes_mainloop { @bl.declare(true,client); $statusb.nbpeer+=1	}		end
  def p2p_forget(client)		invoke_in_shoes_mainloop { @bl.declare(false,client); $statusb.nbpeer-=1 }	end
  def p2p_update_nbfile(n)		invoke_in_shoes_mainloop { $statusb.nbfiles=n }			end
  def p2p_is_suspended?()
	$statusb.is_suspend() 
  end
  def started()
	Dir[$pattern].each { |f| p2p_receiving(f,"") }
  end
  def view(f)
  end
end
if File.exists?("s2s.rb")
  FileUtils.mkdir_p("TEST/ME")
  Dir.chdir("TEST/ME")
end
VERSION="G1.0" unless defined?(VERSION)
# w=600 h=500
Shoes.app title: "S2S V#{VERSION} #{Dir.pwd} #{server} ",width: 600,  height: 500 do
	$app=self
	define_async_thread_invoker(0.5)
	stack height: 1.0 do
		background "#204040".."#205050" 
		fill "#909090"
		stack height: 100  do
			#background "#50A0A0".."#507070" 
			background "#70C0C0".."#70A0A0" 
			my_button(450,10,"View")   {  view(ask_open_file()) }
			#my_button(320,10,"Repos.")   { alert($statusb.nbfiles);  $statusb.nbfiles=999 ;}
			my_button(450,40,"Pause")    { $statusb.is_suspend=true }
			my_button(450,70,"Restart")  { $statusb.is_suspend=false }
			#my_button(450,10,"Export")   { alert("CouCoue") }
			#my_button(450,40,"Import")      { alert("pause") }
			#my_button(450,70,"Exit")     { Thread.new {sleep 0.5; exit!} }
        end
		stack height: 385 do @bl=blackboard(false) end
		stack height: 100  do status_barr( 482 ) end
	end
	puts "\n"*6
	started()
end