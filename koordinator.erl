-module(koordinator).
-export([start/0, start/1, initial/2]).
-author("Aleksandr Nosov, Raimund Wege").

%%  ____ _____  ___  _____ _____
%% / ___|_   _|/ _ \|  _  \_   _|
%% |___ | | | |  _  |  _ <  | |
%% |____/ |_| |_| |_|_| |_| |_|

start() ->
    spawn(koordinator, start, [tools:getKoordinatorConfigData()]).
start({Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname}) ->
    register(Koordinatorname, self()),
    case get_nameservice(Nameservicenode) of
	{ok, Nameservice} ->
        Nameservice ! {self(), {rebind, Koordinatorname, node()}},
        log("Koordinator wurde gebunden");
	{error, Reason} ->
	    log(lists:concat(["Fehler: ", Reason])),
	    exit(killed)
    end,
    log("initial"),
    initial([], {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname}).

%%  _ __  _________ _  ___  _
%% | |  \| | |_   _| |/ _ \| |
%% | |     | | | | | |  _  | |__
%% |_|_|\__|_| |_| |_|_| |_|____|

initial(Prozesse, {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname}) ->
    receive
	{getsteeringval, Starter} ->
        log("Steeringval Anfrage"),
	    Starter ! {steeringval, Arbeitszeit, Termzeit, Ggtprozessnummer},
	    initial(Prozesse, {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname});
	{hello, Clientname} ->
        log(lists:concat(["Hello von: ", Clientname])),
	    case lists:member(Clientname, Prozesse) of
		true ->
            log(lists:concat([Clientname], "existiert bereits")),
		    initial(Prozesse, {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname});
		false ->
            log(lists:concat([Clientname], "wurde hinzugefügt")),
		    initial([Clientname|Prozesse], {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname})
	    end;
	bereit ->
        log("bereit"),
        bereit(Prozesse, {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname});
	reset ->
        log("reset"),
        reset(Prozesse, {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname});
	beenden ->
        log("beenden"),
        kill(Nameservicenode, Prozesse)
    end.

%%  _____ _____ _____ _____________
%% |  _  | ____|  _  \ ____| |_   _|
%% |  _ <| __|_|  _ <| __|_| | | |
%% |_____|_____|_| |_|_____|_| |_|

bereit(Prozesse, {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname}) ->
    receive
    juhu ->
        bereit(Prozesse, {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname})
    end.

%%  _____ _____ ____ _____ _____
%% |  _  \ ____/ ___| ____|_   _|
%% |  _ <| __|_|___ | __|_  | |
%% |_| |_|_____|____/_____| |_|

reset(Prozesse, {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname}) ->
    kill(Nameservicenode, Prozesse),
    initial([], {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname}).

%%  _   _ _ _     _
%% | |_| | | |   | |
%% |  _ <| | |___| |___
%% |_| |_|_|_____|_____|

kill(Nameservicenode, Prozesse) when is_list(Prozesse) ->
    log("Killing all processes"),
    lists:map(fun(X)-> send_message(Nameservicenode ,X , kill) end, Prozesse).

%%  _     _____ _____
%% | |   |  _  |  ___|
%% | |___| |_| | |_  |
%% |_____|_____|_____|

log(Message) ->
    Name = lists:concat(["Koordinator@", net_adm:localhost()]),
    NewMessage = lists:concat([Name, werkzeug:timeMilliSecond(), " ", Message, "\n"]),
    werkzeug:logging(lists:concat("NKoordinator.log"), NewMessage).

%%  _____ _____ ___ ___ ___ ___ _   _ __  _ _ _____  ___  _____ _____
%% |  ___|  _  |   V   |   V   | | | |  \| | |  ___|/ _ \|_   _| ____|
%% | |___| |_| | |\_/| | |\_/| | |_| |     | | |___|  _  | | | | __|_
%% |_____|_____|_|   |_|_|   |_|_____|_|\__|_|_____|_| |_| |_| |_____|

get_nameservice(Nameservicenode) -> 
    case net_adm:ping(Nameservicenode) of
        pang -> 
            log("Nameservicenode nicht erreichbar"),
            {error, no_nameservicenode};
        pong -> 
            global:sync(),
            Nameservice = global:whereis_name(nameservice),
            {ok, Nameservice}
    end.

get_service(Nameservicenode, Name) ->
    case get_nameservice(Nameservicenode) of
	Error = {error, Reason}->
	    log(lists:concat(["Cannot get service ", Name, " because of ", Reason])),
	    Error;
	{ok, Nameservice} ->
    	log(lists:concat(["Asking nameservice for ", Name])),
	    Nameservice ! {self(), {lookup, Name}},
	    receive
		not_found ->
		    log(lists:concat(["Cannot find ", Name])),
		    {error, service_not_found};
		Service = {NameOfService, Node} when is_atom(NameOfService) and is_atom(Node) -> 
		    {ok, Service}
	    end
    end.
    
send_message(Nameservicenode, Name, Message) ->
    case get_service(Nameservicenode, Name) of
	Error = {error, Reason} ->
	    log(lists:concat(["Cannot send message to ", Name, " because of ", Reason])),
	    Error;
	{ok, Service} ->
	    log(lists:concat(["Sending message to ", Name])),
	    Service ! Message
    end.