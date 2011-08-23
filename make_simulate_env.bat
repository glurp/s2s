rem with Windows/msys...

rm -r TEST

mkdir TEST
mkdir TEST\T1
mkdir TEST\T2
mkdir TEST\T3

touch TEST/T2/a.rb
touch TEST/T2/b.rb
touch TEST/T2/a.txt
touch TEST/T2/a.dll
touch TEST/T2/a.exe
touch TEST/T2/a.so
mkdir TEST\T2\proj
touch TEST/T2/proj/p.rb
mkdir TEST\T2\proj/lib
touch TEST/T3/X.rb
touch TEST/T3/Y.png


cd TEST
cd T1 && start "server"  cmd /k "ruby ../../p2p.rb shoesdev server druby://localhost:50500"
cd ..
cd T2 && start "client1" cmd /k "ruby ../../p2p.rb shoesdev client druby://localhost:50500"
cd ..
cd T3 && start "client2" cmd /k "ruby ../../p2p.rb shoesdev client druby://localhost:50500"
cd ..
cd ..
sleep 10
:DD
	cls
	dir/s/b TEST
 	sleep 2
goto DD
 





