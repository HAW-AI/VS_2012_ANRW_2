-module(ggt).
-export([start/8]).
-import(tools,[its/1,log/3]).
-author("Aleksandr Nosov, Raimund Wege").

start(Workingtime, Termination, Processnumber, Starternumber, Group, Team, Nameservice, Coordinator) ->
	Name=its(Group)++its(Team)++its(Processnumber)++its(Starternumber), 
	{ok, Hostname}=inet:gethostname(),
	register(Name,self()),
	Nameservice ! {self(),{rebind,Name,node()}},
	receive 
		ok -> log("Rebind erfolgreich ausgefuehrt\n",Name,Hostname)
	end,
	Coordinator ! {hello, Name},
	receive 
		{setneighbors,LeftN,RightN} -> log("Hallo Antwort mit: "++LeftN++" links und "++RightN++" rechts\n",Name,Hostname)
	end,
	receive 
		{setpm,NewMi} -> log("Init Mi: "++its(NewMi)++"\n",Name,Hostname),
		{ok,Timer}=timer:apply_after(ggt,init_termination,[LeftN,Name]),			
		loop(Workingtime,Coordinator,Name,LeftN,RightN,NewMi,Timer,Termination)
	end.

loop(Workingtime,Coordinator,Name,LeftN,RightN,Mi,Timer,Termination) ->
	{ok, Hostname}=inet:gethostname(),
	receive
		{sendy,Y} ->
			if Y < Mi -> 
				CMi = ((Mi-1) rem Y) +1,
				Coordinator ! {briefmi,{Name,CMi,time()}},
				log("Berechete MI:"++its(CMi)++"\n",Name,Hostname),
				LeftN ! CMi,
				RightN ! CMi;
			true -> CMi = Mi
			end,
			timer:sleep(Workingtime),
			timer:cancel(Timer),
			timer:apply_after(ggt,init_termination,[LeftN,Name]),			
			loop(Workingtime,Coordinator,Name,LeftN,RightN,CMi,Timer,Termination);
		{abstimmung,Initiator} ->
			NowTime = timer:now_diff(Timer, now()) < Termination/2000,
			if  Initiator =:= LeftN ->  
					log("Abstimmung empfangen vom Nachbar links\n",Name,Hostname),
					log("Abstimmung an Koordinator mit: "++its(Mi)++"\n",Name,Hostname),
					Coordinator ! {briefterm,{Name,Mi,time()}};
				 NowTime ->
					log("Abstimmung weiterleiten\n",Name,Hostname),
					init_termination(RightN,Name);
				true -> log("Abstimmung ignorieren\n",Name,Hostname)
			end,
			loop(Workingtime,Coordinator,Name,LeftN,RightN,Mi,Timer,Termination);
		{tellmi,From}-> 
			From ! Mi,
			log("Sage Mi weiter\n",Name,Hostname),
			loop(Workingtime,Coordinator,Name,LeftN,RightN,Mi,Timer,Termination);
		kill-> done
	end.
%% Terminierung initialisieren.
init_termination(Host,Name) ->
	{ok, Hostname}=inet:gethostname(),
	log("Initialisiere Terminierung\n",Name,Hostname),
	Host ! {abstimmung,Name}.