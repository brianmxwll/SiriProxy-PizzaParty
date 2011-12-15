require 'cora'
require 'siri_objects'

#############
# This is a plugin for SiriProxy that will allow you to order a pizza
#############

#Not particularly a fan of globals... but there aren't many good options
#for storing config stuff if you don't a) want to parse a text file 
#and b) want to install/use a third party library. Sorry. 
$user = 'user goes here'
$pass = 'password goes here'

class Pizza
	def initialize
		@toppings_cmd = ""
		@toppings_current = []
		@size = ""
		@crust = ""
		@toppingNames = [["u","Sliced Italian Sausage"],["i","Italian Sausage"],["b","Beef"],
		  ["c","Bacon"],["h","Ham"],["k","Chicken"],["p","Pepperoni"],["s","Philly Steak"],
		  ["a","Pineapple"],["d","Cheddar Cheese"],["e","Bananan Peppers"],["f","Feta Cheese"],
		  ["g","Green Peppers"],["j","Jalapeno Peppers"],["l","Black Olives"],["m","Mushrooms"],
		  ["n","Provolone Cheese"],["o","Onions"],["q","Roasted Red Peppers"],["r","Shredded Parmesean Asiago"],
		  ["t","Diced Tomatoes"],["v","Green Olives"],["w","Hot Sauce"],["y","Spinach"]]
	end

	def parseToppings(text)
		text.downcase!
		@toppingNames.each do |topping|
			if text.include? topping[1].downcase #If topping was found in their text
				if !@toppings_cmd.include? topping[0] #If we haven't already added it
					@toppings_cmd << topping[0]
					@toppings_current << topping[1]
				end
				text = text.gsub(topping[1].downcase, "")
			end
		end
		@toppings_current
	end

	def setSize(text)
		if text.downcase.include? "small"
			@size = "small"
		elsif text.downcase.include? "medium"
			@size = "medium"
		elsif text.downcase.include? "extra"
			@size = "x-large"
		elsif text.downcase.include? "large"
			@size = "large"
		else
			return false
		end
		return true
	end

	def setCrust(text)
		if text.downcase.include? "toss"
			@crust = "handtoss"
		elsif text.downcase.include? "dish"
			@crust = "deepdish"
		elsif text.downcase.include? "thin"
			@crust = "thin"
		elsif text.downcase.include? "brooklyn"
			@crust = "brooklyn"
		else
			return false
		end
		return true
	end

	def print
		return @size + " " + @crust + " pizza with " + self.getToppingsList
	end

	def getToppingsList
		tmp = Array.new(@toppings_current)
		if tmp.length > 1
			tmp[-1] = "and " + tmp[-1]
			return tmp.join(", ")
		else
			return @toppings_current[0]
		end
	end

	def getCommand
		return "-" + @toppings_cmd + " 1 " + @size + " " + @crust
	end
end

class SiriProxy::Plugin::PizzaParty < SiriProxy::Plugin

  @classVariable = ""
	#request_completed
	def initialize(config)
    @pizzas = []
		@orderWords = ["first","second","third","fourth","fifth","sixth","seventh","eighth"]
  end
  
	listen_for /toppings (.*)/i do |toppings|
		p = Pizza.new
		p.parseToppings(toppings)
	end

	listen_for /order(.*)pizza/i do |word|
		say "Alright. I can order pizza for you."
		orderPizza()
		#p = Pizza.new
		#p.parseToppings 'Pepperoni Bacon'
		#p.setCrust 'hand toss'
		#p.setSize 'medium'
		
		#p2 = Pizza.new
		#p2.parseToppings 'Chicken Feta Cheese'
		#p2.setCrust 'hand toss'
		#p2.setSize 'medium'
		
		#p3 = Pizza.new
		#p3.parseToppings 'Ham Pineapple'
		#p3.setCrust 'hand toss'
		#p3.setSize 'medium'

		#@pizzas << p
		#@pizzas << p2
		#@pizzas << p3
		
		happy = false
		while not happy
			response = ask "Would you like another pizza?"
			if response.downcase.include? "yes"
				orderPizza()
			else
				happy = true
			end
		end
		
		printOrder 
		
		write
		cmd = []
		cmd << 'python ' + getCwd + '/pizza_py_party.py'
		cmd << '-U ' + $user
		cmd << '-P ' + $pass
		cmd << '-O 9179' #For demo purposes. Add coupon with ID 9179, to save me money. Incorporate real coupon behavior into Siri later. 
		cmd << '-I ' + getCwd + '/batch.txt'
		conn = IO.popen(cmd.join(' '), 'w+')

		
		response = conn.gets.strip.split('_')
		price = response[0]
		wait = response[1]
		wait = wait.gsub("Approx.","approximately")
		wait = wait.gsub("-"," to ")
		say "Your final price will be " + price + " and your wait time will be " + wait + "." 	
		response = ask "Do you want to complete the order?"
		if (response.downcase.strip == "yes")
			cmd << " -F"
			conn = IO.popen(cmd.join(' '), 'w+')
			conn.close
			say "The order has been placed. Check your email for confirmation. Enjoy!"
		end
		request_completed
	end

	def orderPizza
		p = Pizza.new
		response = ask "What would you like on your " + @orderWords[@pizzas.length] + " pizza?"
		begin
			added = p.parseToppings(response)
			say "Your " + @orderWords[@pizzas.length] + " pizza currently has " + p.getToppingsList + "."
			response = ask "Would you like to add any other toppings?"
		end while not (response.downcase.strip == "no")
		
		happy = false
		while not happy
			response = ask "What kind of crust would you like? (Handtoss, deepdish, thin, Brooklyn style)", spoken: "What kind of crust would you like?"
			happy = p.setCrust(response)
			if not happy
				say "I'm sorry, I didn't get that."
			end
		end

		happy = false
		while not happy
			response = ask "What size would you like? (Small, medium, large, extra large)", spoken: "What size would you like?"
			happy = p.setSize(response)
			if not happy
				say "I'm sorry, I didn't get that."
			end
		end
		
		@pizzas << p
	end

	def printOrder
		@pizzas.each_with_index do |p, index|
			say "Your " + @orderWords[index] + " pizza is a " + p.print + "."
		end
	end

	def write
		puts getCwd
		File.open(getCwd + "/batch.txt","w") do |f|
			@pizzas.each do |pizza|
				f.puts pizza.getCommand
			end
		end
	end
	
	def getCwd
		return File.dirname(__FILE__)
	end 

end
