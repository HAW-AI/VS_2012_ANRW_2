-module(starter).
-compile(export_all).

start()-> start(1).

start(AnzahlStarter) when AnzahlStarter > 0 -> lists:map(fun(X)->spawn(fun()->init(X) end) end,lists:seq(1,AnzahlStarter)).

init(Starternr)->
    {Koordinatorname,Nameservicenode,Team,Gruppe,Starternr}=tools:getGgtConfigData(),
	Locfunc=fun(Message) -> log(Message,Starternr) end,
	case tools:get_nameservice({Nameservicenode,Locfunc}) of
		{ok,_}->
			case tools:get_service({Koordinatorname,Nameservicenode,Locfunc}) of
				{ok,Koordinator}->
					log("Koordinator nach steeringval fragen",Starternr),
					Koordinator ! {getsteeringval,self()},
					loop_steeringval({Koordinatorname,Team,Gruppe,Nameservicenode,Starternr})
			end
    end.
    
    
loop_steeringval({Koordinatorname,Team,Gruppe,Nameservicenode,Starternr})->    
    receive
		{steeringval,ArbeitsZeit,TermZeit,GGTProzessnummer} ->
			log(lists:concat(["Starte ",GGTProzessnummer," GGT mit ",ArbeitsZeit," Arbeitszeit und ",TermZeit," Terminierungszeit"]),Starternr),
			lists:map(fun(X)-> ggt:start(ArbeitsZeit,TermZeit,X,Starternr,Gruppe,Team,Nameservicenode,Koordinatorname) end, lists:seq(1,GGTProzessnummer));
		kill -> 
			terminate(Starternr);
		_Any -> 
			log("Unexpected message",Starternr),
			loop_steeringval({Koordinatorname,Team,Gruppe,Nameservicenode,Starternr})
    end.

terminate(Starternr)->
    	    log("Received kill command",Starternr),
	    exit(normal).

log(Message,Starternr)->
    Name = lists:concat(["ggt",Starternr,"@",inet:hostname()]),
    NewMessage = lists:concat([Name,werkzeug:timeMilliSecond()," ",Message,io_lib:nl()]),
    werkzeug:logging(lists:concat([Name,".log"]),NewMessage).
