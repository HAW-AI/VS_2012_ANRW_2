-module(tools).
-export([minKey/1,maxKey/1,localtime/0,nextKey/2,getClientConfigData/0,getServerConfigData/0]).
-author("Aleksandr Nosov").

getClientConfigData() ->
	{ok, Configurations} = file:consult("client.cfg"),
	Clients = proplists:get_value(clients, Configurations),
	Lifetime = proplists:get_value(lifetime, Configurations),
	Servername = proplists:get_value(servername, Configurations),
	Intervall = proplists:get_value(sendeintervall, Configurations),
	{Clients, Lifetime, Servername, Intervall}.


getServerConfigData() ->
	{ok, Configurations} = file:consult("server.cfg"),
	LiTime = proplists:get_value(lifetime, Configurations),
	ReTime = proplists:get_value(clientlifetime, Configurations),
	Servername = proplists:get_value(servername, Configurations),
	DQ_limit = proplists:get_value(dlqlimit, Configurations),
	%%Difftime = proplists:get_value(difftime, Configurations), keine Anhnung wofur man das braucht.
	{Servername,DQ_limit,LiTime,ReTime}.

minKey([]) -> 0;
minKey([X,Y|Tail])-> minKey(X,Y,Tail);
minKey([X|[]])-> X.
minKey(X,Y,[Head|Tail]) when X < Y -> minKey(X,Head,Tail);
minKey(X,Y,[Head|Tail]) when X > Y -> minKey(Y,Head,Tail);
minKey(X,Y,[]) when X >= Y -> Y;
minKey(X,Y,[]) when X < Y -> X.

maxKey([]) -> 0;
maxKey([X,Y|Tail])-> maxKey(X,Y,Tail);
maxKey([X|[]])-> X.
maxKey(X,Y,[Head|Tail]) when X > Y -> maxKey(X,Head,Tail);
maxKey(X,Y,[Head|Tail]) when X < Y -> maxKey(Y,Head,Tail);
maxKey(X,Y,[]) when X < Y -> Y;
maxKey(X,Y,[]) when X >= Y -> X.


nextKey(X,Y,Z,List) when X < Z, Z < Y   -> nextKey(X,Z,List);
nextKey(X,Y,_,[Head|Tail]) -> nextKey(X,Y,Head,Tail);
nextKey(_,Y,_,[]) -> Y.
nextKey(X,Y,[]) when X < Y -> Y;
nextKey(X,Y,[]) when X >= Y -> X;
nextKey(X,Y,[Head|Tail]) when X >= Y -> nextKey(X,Head,Tail);
nextKey(X,Y,[Head|Tail]) when X < Y -> nextKey(X,Y,Head,Tail).
nextKey(X,[Head|Tail]) -> nextKey(X,Head,Tail);
nextKey(_,[]) -> 0;
nextKey(_,_) -> 0.


%%Localtime in Sek.
localtime()->
	{_, Secs, _} = now(),
	Secs.
	
log(Message,ClientID,Hostname) ->
	werkzeug:logging("client_"++integer_to_list(ClientID)++Hostname++".log",Message).
	
%% Ist fur die Zeit T blockiert.	
sleep(T) ->
	receive
	after
		T -> 
			true
	end.
its(Integer) ->
	integer_to_list(Integer).