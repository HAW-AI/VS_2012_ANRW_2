-module(koordinator).
-export([start/0, start/1]).
-author("Aleksandr Nosov, Raimund Wege").

%%  ____ _____  ___  _____ _____
%% / ___|_   _|/ _ \|  _  \_   _|
%% |___ | | | |  _  |  _ <  | |
%% |____/ |_| |_| |_|_| |_| |_|

start() -> spawn(koordinator, start, [tools:getKoordinatorConfigData()]).
start({Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname}) ->
    log("start"),
    register(Koordinatorname, self()),
    case get_nameservice(Nameservicenode) of
	{ok, Nameservice} ->
        Nameservice ! {self(), {rebind, Koordinatorname, node()}},
        log("Koordinator wurde gebunden");
	{error, Reason} ->
	    log(lists:concat(["Fehler: ", Reason])),
	    exit(killed)
    end,
    initial([], {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname}).

%%  _ __  _________ _  ___  _
%% | |  \| | |_   _| |/ _ \| |
%% | |     | | | | | |  _  | |__
%% |_|_|\__|_| |_| |_|_| |_|____|

initial(Prozesse, {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname}) ->
    log("initial"),
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
        if  length(Prozesse) < 3 ->
            log("es sind noch nicht genug Prozesse angemeldet"),
            initial(Prozesse, {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname});
        true ->
            log("Nachbarn bekannt geben"),
            ProzesseGemischt = lists:map(fun({_, X}) -> X end, lists:keysort(1, lists:map(fun(X) -> {random:uniform(), X} end, Prozesse))),
            ProzesseMitIndex = lists:zip(lists:seq(1, length(ProzesseGemischt)), ProzesseGemischt),
            ProzesseMitNachbarn = lists:map(fun({Index, Prozess}) -> {Prozess, nachbarn(Index, ProzesseMitIndex)} end, ProzesseMitIndex),
            lists:map(fun({Prozess, {Left, Right}}) -> send_message(Nameservicenode, Prozess, {setneighbors, Left, Right}) end, ProzesseMitNachbarn),
            bereit(Prozesse, {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname})
        end;
	beenden ->
        beenden(Prozesse, {Nameservicenode})
    end.

nachbarn(Index, ProzesseMitIndex) when is_integer(Index) and is_list(ProzesseMitIndex) ->
    Length = length(ProzesseMitIndex),
    if  Index == 1 -> {lists:nth(Length, ProzesseMitIndex), lists:nth(Index + 1, ProzesseMitIndex)};
        Index == Length -> {lists:nth(Index - 1, ProzesseMitIndex), lists:nth(1, ProzesseMitIndex)};
    true ->
        {lists:nth(Index - 1, ProzesseMitIndex), lists:nth(Index + 1, ProzesseMitIndex)}
    end.

%%  _____ _____ _____ _____________
%% |  _  | ____|  _  \ ____| |_   _|
%% |  _ <| __|_|  _ <| __|_| | | |
%% |_____|_____|_| |_|_____|_| |_|

bereit(Prozesse, {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname}) ->
    log("bereit"),
    receive
    {berechnen, Ggt} ->
        berechnen(Prozesse, Ggt, {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname});
    reset ->
        reset(Prozesse, {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname});
    beenden ->
        beenden(Prozesse, {Nameservicenode})
    end.
    
%%  _____ _____ _____ _____________   _ __  _ _____ __  _
%% |  _  | ____|  _  \ ____|  ___| |_| |  \| | ____|  \| |
%% |  _ <| __|_|  _ <| __|_| |___|  _  |     | __|_|     |
%% |_____|_____|_| |_|_____|_____|_| |_|_|\__|_____|_|\__|

berechnen(Prozesse, Ggt, {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname}) ->
    lists:map(fun(P) -> G = ggt(Ggt), log(lists:concat(["MI: ", G, " setpm ", P])), send_message(Nameservicenode, P, {setpm, G}) end, Prozesse),
    lists:map(fun(P) -> G = ggt(Ggt), log(lists:concat(["Y:  ", G, " sendy ", P])), send_message(Nameservicenode, P, {sendy, G}) end, lists:sublist(Prozesse, n(Prozesse))),
    berechnen_loop(Prozesse, Ggt, {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname}).

n(Prozesse) when is_list(Prozesse) ->
    case round(length(Prozesse) * 15 / 100) of
	N when N < 2 -> 2;
	N -> N
    end.

berechnen_loop(Prozesse, Ggt, {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname}) ->
    receive
    {briefmi, {Clientname, CMi, CZeit}} ->
	    log(lists:concat([Clientname, " calculated new Mi ", CMi, " at ", CZeit])),
	    berechnen_loop(Prozesse, Ggt, {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname});
	{briefterm, {Clientname, CMi, CZeit}} ->
	    log(lists:concat([Clientname, " terminated with Mi ", CMi, " at ", CZeit])),
	    berechnen_loop(Prozesse, Ggt, {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname});
    {berechnen, Ggt} ->
        berechnen(Prozesse, Ggt, {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname});
	reset ->
        reset(Prozesse, {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname});
	beenden ->
        beenden(Prozesse, {Nameservicenode})
    end.

ggt(GGT) -> GGT * lists:foldl(fun(X, Y) -> X * math:pow(Y, random:uniform(3) - 1) end, 1, [3, 5, 11, 13, 23, 37]).

%%  _____ _____ ____ _____ _____
%% |  _  \ ____/ ___| ____|_   _|
%% |  _ <| __|_|___ | __|_  | |
%% |_| |_|_____|____/_____| |_|

reset(Prozesse, {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname}) ->
    log("reset"),
    kill(Nameservicenode, Prozesse),
    initial([], {Arbeitszeit, Termzeit, Ggtprozessnummer, Nameservicenode, Koordinatorname}).

%%  _____ _____ _____ __  _ _____ _____ __  _
%% |  _  | ____| ____|  \| |  _  \ ____|  \| |
%% |  _ <| __|_| __|_|     | |_| | __|_|     |
%% |_____|_____|_____|_|\__|_____/_____|_|\__|

beenden(Prozesse, {Nameservicenode}) ->
    log("beenden"),
    kill(Nameservicenode, Prozesse).

%%  _   _ _ _     _
%% | |_| | | |   | |
%% |  _ <| | |___| |___
%% |_| |_|_|_____|_____|

kill(Nameservicenode, Prozesse) when is_list(Prozesse) ->
    log("killing all processes"),
    lists:map(fun(X)-> send_message(Nameservicenode ,X , kill) end, Prozesse).

%%  _     _____ _____
%% | |   |  _  |  ___|
%% | |___| |_| | |_  |
%% |_____|_____|_____|

log(Message) ->
    Name = lists:concat(["koordinator@", net_adm:localhost()]),
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
	Error = {error, Reason} ->
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