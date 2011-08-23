require 'green_shoes'
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

####################### Physique space : a shape is a file which arrive by p2p


class Blackboard  < Shoes::Widget
  include ChipMunk
  def initialize()
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

	  #p balls[0][1].methods - Object.methods
      #p space.gravity
	  #p space.gravity= vec2(5,10)
	  #spy

	  200.times { balls <<  [0,drop_ball() ] }
	  animate(10) do
			balls <<  [0,drop_ball() ] while balls.size<350 if (balls.size<70)
			#declare("#{200+(Time.now.to_f*10).round%10}")
			#destroy("#{200+(Time.now.to_f*10+1).round%10}")
	  end
	  animate(7) do
		unless $statusb.is_suspend
			10.times { space.step 0.05 }
			r=[]
			balls.each{|no,ball|  ball.cp_move; (no<100 || ball.top<460 ) ? (r << [no+1,ball])  : ball.cp_remove(space) }
			balls=r
			#p [r.size,r[0][0],r[0][1].top,$statusb.nbfiles]  rescue nil
			$statusb.nbfiles=balls.size
			r=nil
		end
	  end
  end
  def drop_ball
	  x0,y0=110,50
	  color= rgb((50+((rand(100)<10) ? rand(200) : rand(30))).to_i ,100+rand(140),200+rand(40)) 
      cp_oval(x0+rand(30), y0+rand(40), 2+rand(4), { fill: color })
  end
  def declare(ip,&blk)
	return if @ip[ip]
	col=@ip.size/25
	lig=@ip.size%25
	x=580-21*col; y=105+10*lig
	@ip[ip]=rect x,y,20,9, fill: "#BB3030"
	t=Time.now
	if blk
	  @ip[ip].click { blk.call }
	else
	  @ip[ip].click { alert("Apparition of #{ip} at #{t}") }
	end
  end
  def destroy(ip)
	return unless @ip[ip]
	@ip[ip].style fill: "#606060" 
	@ip.delete(ip)
  end
end

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
	end
end

class MyButton < Shoes::Widget
  def initialize(left,top,text)
	r = rect       left,          top,      120,25,  fill: "#607070".."#80A0A0", strokewidth: 1, curve: 10, stroke: black
	p= para  text, left: left+10, top: top+4      ,  stroke: "#D0D0D0"

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
			@nbf=inscription   'xxxxxxxx'    ,stroke: "#909090" , width: 50  ,fill: "#E0E0E0"
			inscription "    Nb Shoers : "   ,stroke: "#E0E0E0" , width: 100,fill: "#909090"
			@nbp=inscription '99'            ,stroke: "#000000" , width: 50
			inscription "    State :  "      ,stroke: "#E0E0E0" , width: 100,fill: "#909090"
			@iss=inscription 'ONLINE'        ,stroke: "#000000" , width: 100
			inscription '_________________'   ,stroke: "#909090" , width: 100,fill: "#909090"
		end
    end
	def nbfiles=(v)
		sv=v.to_s
		@nbf.text= bg(fg(sv, "#909090"),"#E0E0E0") if sv!=@nbfiles
		@nbfiles=sv
	end
	def nbpeer=(v)
		@nbp.text=v.to_s  if v.to_s!=@nbpeer
		@nbpeer=v.to_s
	end
	def is_suspend=(v)
		@iss.text=v ?  "OFFLINE" : "ONLINE" if v!=is_suspend
		@is_suspend=v
	end
end

# w=600 h=500
Shoes.app title: 'S2S Shoes share code !' do
	stack height: 1.0 do
		background "#204040".."#205050" 
		fill "#909090"
		stack height: 100  do
			#background "#50A0A0".."#507070" 
			background "#70C0C0".."#70A0A0" 
			my_button(180,10,"Configuration")   { alert("CouCoue") }
			my_button(320,10,"Repos.")   { alert($statusb.nbfiles);  $statusb.nbfiles=999 ;}
			my_button(320,40,"Pause")    { $statusb.is_suspend=true }
			my_button(320,70,"Restart")  { $statusb.is_suspend=false }
			my_button(450,10,"Export")   { alert("CouCoue") }
			my_button(450,40,"Import")      { alert("pause") }
			my_button(450,70,"Exit")     { Thread.new {sleep 0.5; exit!} }
        end
		stack height: 385 do bl=blackboard end
		stack height: 100  do status_barr( 482 ) end
	end
	puts "\n"*6
end
