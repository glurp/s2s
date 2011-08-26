rem with Windows/msys...

rm -r TEST

mkdir TEST
mkdir TEST\T1
mkdir TEST\T2
mkdir TEST\T3
mkdir TEST\T4
cat s2s.rb p2p > x.x
cp x.x TEST/T2/a.rb
cp x.x TEST/T2/b.rb
cp x.x TEST/T2/a.txt
cp x.x TEST/T2/a.dll
cp x.x TEST/T2/a.exe
cp x.x TEST/T2/a.so
mkdir TEST\T2\proj
cp x.x TEST/T2/proj/p.rb
mkdir TEST\T2\proj/lib
cp x.x TEST/T3/X.rb
cp x.x TEST/T3/Y.png
rm x.x

cd TEST
cd T1 && start "server"  cmd /k "ruby ../../p2p.rb shoerdev server druby://homeregis.dyndns.org:50500"
cd ..
cd T2 && start "client1" cmd /k "ruby ../../p2p.rb shoerdev client druby://homeregis.dyndns.org:50500"
cd ..
cd T3 && start "client2" cmd /k "ruby ../../p2p.rb shoerdev client druby://homeregis.dyndns.org:50500"
cd ..
cd T4 && start "gui"     cmd /k "ruby ../../s2s.rb shoerdev  druby://homeregis.dyndns.org:50500"
cd ..
cd ..
sleep 10
:DD
cls
du TEST/* -s
sleep 5
goto DD
 





