-module(ggt).
-export([start/8]).
-import(tools,[its/1,log/3]).
-author("Aleksandr Nosov, Raimund Wege").

start(Workingtime, Termination, Processnumber, Starternumber, Group, Team, Nameservicenode, Coordinatorname) ->
	Name=its(Group)++its(Team)++its(Processnumber)++its(Starternumber), 
	{ok, Hostname}=inet:gethostname(),
	register(Name,self()),
	Logfunc=fun(Message) -> log(Message,Name,Hostname) end,
	case tools:get_namesrevice(Nameservicenode,Logfunc) of
		{ok,Nameservice} ->	
			Nameservice ! {self(),{rebind,Name,node()}},
			case tools:get_service({Coordinatorname,Nameservice,Logfunc}) of
				{ok,Coordinator} ->
					receive 
						ok -> Logfunc("Rebind erfolgreich ausgefuehrt\n")
					end,
					Coordinator ! {hello, Name},
					receive 
						{setneighbors,LeftN,RightN} -> Logfunc(["Hallo Antwort mit: ",LeftN," links und ",RightN," rechts\n"])
					end,
					receive 
						{setpm,NewMi} -> Logfunc(["Init Mi: ",its(NewMi),"\n"]),
						{ok,Timer}=timer:apply_after(ggt,init_termination,[LeftN,Name]),			
						loop(Workingtime,Coordinator,Name,LeftN,RightN,NewMi,Timer,Termination)
					end
			end
	end.

loop(Workingtime,Coordinator,Name,LeftN,RightN,Mi,Timer,Termination) ->
	{ok, Hostname}=inet:gethostname(),
	Logfunc=fun(Message) -> log(Message,Name,Hostname) end,
	receive
		{sendy,Y} ->
			if Y < Mi -> 
				CMi = ((Mi-1) rem Y) +1,
				Coordinator ! {briefmi,{Name,CMi,time()}},
				Logfunc(["Berechete MI:",its(CMi),"\n"]),
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
					Logfunc("Abstimmung empfangen vom Nachbar links\n",Name,Hostname),
					Logfunc("Abstimmung an Koordinator mit: "++its(Mi)++"\n"),
					Coordinator ! {briefterm,{Name,Mi,time()}};
				 NowTime ->
					Logfunc("Abstimmung weiterleiten\n"),
					init_termination(RightN,Name);
				true -> Logfunc("Abstimmung ignorieren\n")
			end,
			loop(Workingtime,Coordinator,Name,LeftN,RightN,Mi,Timer,Termination);
		{tellmi,From}-> 
			From ! Mi,
			Logfunc("Sage Mi weiter\n",Name,Hostname),
			loop(Workingtime,Coordinator,Name,LeftN,RightN,Mi,Timer,Termination);
		kill-> done
	end.
%% Terminierung initialisieren.
init_termination(Host,Name) ->
	{ok, Hostname}=inet:gethostname(),
	log("Initialisiere Terminierung\n",Name,Hostname),
	Host ! {abstimmung,Name}.