#!/bin/bash
# Unix bash ...

[ -d TEST ] && rm -rf TEST

mkdir TEST
mkdir TEST/T1
mkdir TEST/T2
mkdir TEST/T3

touch TEST/T2/a.rb
touch TEST/T2/b.rb
touch TEST/T2/c.png
touch TEST/T2/a.txt
#touch TEST/T2/a.dll
#touch TEST/T2/a.exe
#touch TEST/T2/a.so
mkdir TEST/T2/proj
touch TEST/T2/proj/p.rb
mkdir TEST/T2/proj/lib

touch TEST/T3/XXXXXXXXXXXX.rb
touch TEST/T3/YYYYYYYYYYYY.png


(
	cd TEST
	(cd T3 ; xterm -geo 140x15+0+400 -T Client2 -e ruby1.9.1 ../../p2p.rb shoesdev client druby://localhost:50500 &) 
	sleep 1
	(cd T2 ; xterm -geo 140x15+0+200 -T Client1 -e ruby1.9.1 ../../p2p.rb shoesdev client druby://localhost:50500 &)
	sleep 1
	(cd T1 ; xterm -geo 140x15+0+0   -T Serveur -e ruby1.9.1 ../../p2p.rb shoesdev server druby://localhost:50500 &)
	cd ..
)
while : 
do
	clear
	date
	find TEST
 	sleep 2
done





