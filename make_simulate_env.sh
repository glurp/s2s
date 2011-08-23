#!/bin/bash
# Unix bash ...
[ $# -gt 0 ] &&  export IPS=$1 || export IPS=localhost

[ -d UTEST ] && rm -rf TEST

mkdir UTEST
mkdir UTEST/T1
mkdir UTEST/T2
mkdir UTEST/T3

touch UTEST/T2/a.rb
touch UTEST/T2/b.rb
touch UTEST/T2/c.png
touch UTEST/T2/a.txt
#touch UTEST/T2/a.dll
#touch UTEST/T2/a.exe
#touch UTEST/T2/a.so
mkdir UTEST/T2/proj
touch UTEST/T2/proj/p.rb
mkdir UTEST/T2/proj/lib

touch UTEST/T3/XXXXXXXXXXXX.rb
touch UTEST/T3/YYYYYYYYYYYY.png


(
	cd UTEST
        (cd T3 ; xterm -geo 140x15+0+400 -T Client2 -e ruby1.9.1 ../../p2p.rb shoesdev client druby://$IPS:50500 &) 
	sleep 1
	(cd T2 ; xterm -geo 140x15+0+200 -T Client1 -e ruby1.9.1 ../../p2p.rb shoesdev client druby://$IPS:50500 &)
	sleep 1
	[ $# gt 0 ] && (cd T1 ; xterm -geo 140x15+0+0   -T Serveur -e ruby1.9.1 ../../p2p.rb shoesdev server druby://$IPS:50500 &)
	cd ..
)
while : 
do
	clear
	date
	find UTEST
 	sleep 2
done





