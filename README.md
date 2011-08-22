S2S : Shoer to Shoers
=====================

Peer 2 peer directory share, for ruby (Shoes) snippets

Presentation
============

A simple p2p application, made for distribute little ruby applications.
GUI is made with Green-Shoes

P2p part is based on an old 9 lines LOC showed by _why.
So this tool is made in souvenir of him.


Usage
=====

Run a client with green-shoes Gui (not ready yet!) :
  > ruby s2s.rb

Run a client without gui: in CLI (no dependency, only ruby 1.9)
  > ruby p2p.rb

Run a 'server' (no dependency , only ruby 1.9) :
  > ruby p2p.rb  shoerdev server  druby://<myip>/:50500  druby://homeregis.dyndns.org/:50500  ...other servers....

Principles
=========

The application try to maintain in each client the same directory content :
- sub directory,
- ruby files
- images rasters
- .txt files

So all clients on the net should have a directory which have exactly the same content.
files types and sizes are limited (size limit: 10KB).
If someone copy a file in his shared-directory, this file will be copied to all other member.

2 types of applications :
- *server* : a application which memorize the list of applications actives, and can give this list to anyone
- *client* : a application share his files with all other client. a *client* is *server* : it keep a list of all client, so a client is a server too.

So servers are useful only at clients start up.
A server is running at homeregis.dyndns.org, so by default, all client take this one as server,
but anybody can run server, it will enter in the ring.


Requirements
============

Ruby (1.9.2 for gui),

Green-shoes for GUI

Chipmunk Windows (so linux seem not supported for GUI)

Access to Internet  without proxy (but it  work on a isolated LAN, run a default server in the LAN)

If firewall :
 
 Create a rule for authorisation on port 50500..50510 for TCP/UDP (for your process ruby)

Refs
====

http://regisaubarede.posterous.com/tag/p2p

https://github.com/ashbb/green_shoes

Status
======

In development,

- p2p.rb : seem OK win/Linux, to be tested on Internet
- s2s.rb : ok as maquette, must be connected to p2p
- Chipmunk in gs : ok, patched (in s2s.rb) for limit the number of dynamic shape

NOTA
I learned English with Rambo, Conan and Monster garage, so sorry for my English :)