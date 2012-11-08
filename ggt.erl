-module(ggt).
-export([start/8,init_termination/4]).
-import(tools,[its/1,log/3]).
-author("Aleksandr Nosov, Raimund Wege").

start(Workingtime, Termination, Processnumber, Starternumber, Group, Team, Nameservicenode, Coordinatorname) ->
	Name=list_to_atom(its(Group)++its(Team)++its(Processnumber)++its(Starternumber)), 
	spawn(fun()-> init(Name,Workingtime, Termination*1000, Nameservicenode, Coordinatorname) end).
	
init(Name, Workingtime, Termination, Nameservicenode, Coordinatorname) ->
	register(Name,self()),
	{ok, Hostname}=inet:gethostname(),
	Logfunc=fun(Message) -> log(Message,atom_to_list(Name),Hostname) end,
	case tools:get_nameservice(Nameservicenode,Logfunc) of
		{ok,Nameservice} ->	
			Nameservice ! {self(),{rebind,Name,node()}},
			receive 
				ok -> Logfunc("Rebind erfolgreich ausgefuehrt\n")
			end,
			case tools:get_service({Coordinatorname,Nameservice,Logfunc}) of
				{ok,Coordinator} ->
					Coordinator ! {hello, Name},
					receive 
						{setneighbors,LeftN,RightN} -> Logfunc(["Hallo Antwort mit: ",atom_to_list(LeftN)," links und ",atom_to_list(RightN)," rechts\n"])
					end,
					{ok,Timer}=timer:apply_after(Termination,ggt,init_termination,[RightN,Name,Nameservice,Logfunc]),
					loop(Nameservice,Workingtime,Coordinator,Name,LeftN,RightN,0,{now(),Timer},Termination)
			end
	end.
loop(Nameservice,Workingtime,Coordinator,Name,LeftN,RightN,Mi,{Time,Timer},Termination) ->
	{ok, Hostname}=inet:gethostname(),
	Logfunc=fun(Message) -> log(Message,Name,Hostname) end,
	receive
		{setpm,NewMi} -> 
			timer:cancel(Timer),
			{ok,T}=timer:apply_after(Termination,ggt,init_termination,[RightN,Name,Nameservice,Logfunc]),
			Logfunc(lists:concat(["Init Mi: ",NewMi,"\n"])),			
			loop(Nameservice,Workingtime,Coordinator,Name,LeftN,RightN,NewMi,{now(),T},Termination);
		{sendy,Y} ->
			Logfunc(lists:concat(["Y:",Y," erhalten","\n"])),
			if Y < Mi ->
				CMi = ((Mi-1) rem Y) + 1,
				Coordinator ! {briefmi,{Name,CMi,werkzeug:timeMilliSecond()}},
				Logfunc(["Berechete MI:",its(CMi),"\n"]),
				%%LeftN ! {sendy,CMi},
                send_message(Nameservice, LeftN, Logfunc,{sendy,CMi}),
                send_message(Nameservice, RightN, Logfunc,{sendy,CMi});
				%%RightN ! {sendy,CMi};
			true -> CMi = Mi
			end,
			timer:sleep(Workingtime),
			timer:cancel(Timer),
			{ok,T}=timer:apply_after(Termination,ggt,init_termination,[RightN,Name,Nameservice,Logfunc]),			
			loop(Nameservice,Workingtime,Coordinator,Name,LeftN,RightN,CMi,{now(),T},Termination);
		{abstimmung,Initiator} ->
			NowTime = timer:now_diff(Time, now()) < Termination/2000,
			if  Initiator =:= LeftN ->  
					Logfunc("Abstimmung empfangen vom Nachbar links\n"),
					Logfunc(lists:concat(["Abstimmung an Koordinator mit: ",Mi,"\n"])),
					Coordinator ! {briefterm,{Name,Mi,werkzeug:timeMilliSecond()}};
				 NowTime ->
					Logfunc(lists:concat(["Abstimmung vom ",Initiator," weiterleiten\n"])),
					init_termination(RightN,Name,Nameservice,Logfunc);
				true -> Logfunc(lists:concat(["Abstimmung vom ",Initiator," ignorieren\n"]))
			end,
			loop(Nameservice,Workingtime,Coordinator,Name,LeftN,RightN,Mi,{now(),Timer},Termination);
		{tellmi,From}-> 
			From ! Mi,
			Logfunc("Sage Mi weiter\n",Name,Hostname),
			loop(Nameservice,Workingtime,Coordinator,Name,LeftN,RightN,Mi,{now(),Timer},Termination);
		kill-> done
	end.

%% Terminierung initialisieren.
init_termination(Host,Name,Nameservice,Logfunc) ->
	{ok, Hostname}=inet:gethostname(),
	log(lists:concat([Host," Initialisiere Terminierung\n"]),Name,Hostname),
    send_message(Nameservice, Host,Logfunc,{abstimmung,Name}).
	%%Host ! {abstimmung,Name}.
    
send_message(Nameservice, Name, Logfunc,Message) ->
    case tools:get_service({Name,Nameservice,Logfunc}) of
	Error = {error, Reason} ->
	    Logfunc(lists:concat(["Cannot send message to ", Name, " because of ", Reason])),
	    Error;
	{ok, Service} ->
	    Logfunc(lists:concat(["Sending message to ", Name])),
	    Service ! Message
    end.