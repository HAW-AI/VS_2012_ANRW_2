-module(koordinator).
-export([start/0, start/1, initial/1]).
-author("Aleksandr Nosov, Raimund Wege").

%%  ____ _____  ___  _____ _____
%% / ___|_   _|/ _ \|  _  \_   _|
%% |___ | | | |  _  |  _ <  | |
%% |____/ |_| |_| |_|_| |_| |_|

start() ->
    start(tools:getKoordinatorConfigData()).
start({Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname}) ->
    register(Koordinatorname, self()),
    case get_nameservice(Nameservicenode) of
	{ok, Nameservice} ->
        Nameservice ! {self(), {rebind, Koordinatorname, node()}},
        werkzeug:logging("NKoordinator.log", "Koordinator wurde gebunden\n");
	{error, Reason} ->
	    werkzeug:logging("NKoordinator.log", lists:concat(["Fehler: ", Reason])),
	    exit(killed)
    end,
    werkzeug:logging("NKoordinator.log", "initial\n"),
    initial({Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname}).

%%  _ __  _________ _  ___  _
%% | |  \| | |_   _| |/ _ \| |
%% | |     | | | | | |  _  | |__
%% |_|_|\__|_| |_| |_|_| |_|____|

initial({Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname}) ->
    receive
	{getsteeringval, Starter} ->
        werkzeug:logging("NKoordinator.log", "Steeringval Anfrage\n"),
	    Starter ! {steeringval, Arbeitszeit, Termzeit, Ggtprozessnummer},
	    initial({Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname});
	{hello, Clientname} ->
        werkzeug:logging("NKoordinator.log", lists:concat(["Hello von: ", Clientname]));
%%	    case lists:member(Clientname, Processes) of
%%		true ->
%%		    initial(S);
%%		false ->
%%		    initial(S#state{processes=[Clientname|Processes]})
%%	    end;
	reset -> 
        werkzeug:logging("NKoordinator.log", "reset\n"),
%%	    kill_all(S),
	    initial({Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname});
	work -> 
        werkzeug:logging("NKoordinator.log", "bereit\n");
%%        prepare_ready(S);
	kill -> 
%%	    kill_all(S),
	    exit(killed)
    end.

%%  _____ _____ _____ _____________
%% |  _  | ____|  _  | ____| |_   _|
%% |  _ <| __|_|  _ <| __|_| | | |
%% |_____|_____|_| |_|_____|_| |_|





get_nameservice(Nameservicenode) -> 
    case net_adm:ping(Nameservicenode) of
        pang -> 
            werkzeug:logging("NKoordinator.log", "Nameservicenode nicht erreichbar\n"),
            {error, no_nameservicenode};
        pong -> 
            global:sync(),
            Nameservice = global:whereis_name(nameservice),
	    {ok, Nameservice}
    end.