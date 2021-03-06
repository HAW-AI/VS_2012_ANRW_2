-module(tools).
-compile(export_all).
-author("Aleksandr Nosov").

getKoordinatorConfigData() ->
	{ok, Configurations} = file:consult("koordinator.cfg"),
	Arbeitszeit = proplists:get_value(arbeitszeit, Configurations),
	Termzeit = proplists:get_value(termzeit, Configurations),
	Ggtprozessnummer = proplists:get_value(ggtprozessnummer, Configurations),
	Nameservicenode = proplists:get_value(nameservicenode, Configurations),
    Koordinatorname = proplists:get_value(koordinatorname, Configurations),
	{Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname}.


getGgtConfigData() ->
	{ok, Configurations} = file:consult("ggt.cfg"),
	Praktikumsgruppe = proplists:get_value(praktikumsgruppe, Configurations),
	Teamnummer = proplists:get_value(teamnummer, Configurations),
	Nameservicenode = proplists:get_value(nameservicenode, Configurations),
	Koordinatorname = proplists:get_value(koordinatorname, Configurations),
	{Praktikumsgruppe, Teamnummer, Nameservicenode, Koordinatorname}.


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

get_nameservice(Nameservicenode,Logfunc) ->
	case net_adm:ping(Nameservicenode) of
	pang -> 
	    Logfunc("Nameservicenode ist nicht verfuegbar!\n"),
	    {error,no_nameservicenode};
	pong -> 
	    global:sync(),
	    Nameservice = global:whereis_name(nameservice),
	    {ok,Nameservice}
    end.

get_service({Servicename,Nameservice,Logfunc})->
	Nameservice ! {self(),{lookup,Servicename}},	
	receive
		not_found ->
			Logfunc(lists:concat(["Service ",Servicename," nicht gefunden\n"])),
			{error,no_koordinator};
		kill ->
			{error,kill_command};
		Service={NameOfService,Node} when is_atom(NameOfService) and is_atom(Node) -> 
			Logfunc(lists:concat(["Service ",Servicename," gefunden\n"])),
			{ok,Service}	    
	end.
		

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
	werkzeug:logging(["client_",ClientID,Hostname,".log"],Message).
	
%% Ist fur die Zeit T blockiert.	
sleep(T) ->
	receive
	after
		T -> 
			true
	end.
its(Integer) ->
	integer_to_list(Integer).