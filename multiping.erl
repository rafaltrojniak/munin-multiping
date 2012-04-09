#!/usr/bin/escript
main(["config"])->
	showConfig();
main([])->
	getValues();
main(Unknown)->
	io:format("Unknown parameters ~p",[Unknown]).


getValues() ->
	Pids=forkPings(getHosts()),
	readResults(Pids).

forkPings([]) ->
	[];
forkPings([Host|HTail]) ->
	Command=lists:concat(["ping -nq ", getPingCommand(), " ", Host]),
	io:format("~s\n",[Command]),
	Pid=open_port({spawn,Command},[]),
	[{Host,Pid}|forkPings(HTail)].

readResults([])->
	ok;
readResults([{Host,Pid}|Tail]) ->
	receive
		{Pid,{data,Data}} ->
			RTT=getRTTFromResponse(Data),
			Lost=getLostFromResponse(Data),
			printSingleVal(Host,RTT,Lost),
			readResults(Tail)
	end.

getRTTFromResponse(Data)->
	case re:run(Data,"min/avg/max.*\\s\\d+(?:\\.\\d+)?/(\\d+(?:\\.\\d+)?)/\\d+(?:\\.\\d+)?",[{capture,all_but_first,list}]) of
		{match,[Val]} -> Val;
		_ -> nomatch
	end.

getLostFromResponse(Data)->
	case re:run(Data,"received, (\\d+)% packet loss, time",[{capture,all_but_first,list}]) of
		{match,[Val]} -> Val;
		_ -> nomatch
	end.

showConfig()->
	io:format("graph_title Multiping\n",[]),
	Hosts=getHosts(),
	lists:foreach(fun(Host)->printSingleConfig(Host) end,Hosts),
	ok.

printSingleConfig(Host) ->
	EHost=escapeHost(Host),
	io:format("~s_rtt.label ~s RTT\n",[EHost,Host]),
	io:format("~s_lost.label ~s Lost packets\n",[EHost,Host]),
	ok.

printSingleVal(Host,RTT,Lost)->
	EHost=escapeHost(Host),
	io:format("~s_rtt.value ~s\n",[EHost,RTT]),
	io:format("~s_lost.value  ~s\n",[EHost,Lost]),
	ok.

getHosts()->
	case os:getenv("host") of 
		false -> [];
		Hosts -> string:tokens(Hosts," \t")
	end.

getPingCommand()->
	case os:getenv("ping_args") of 
		false -> "-c 5 ";
		Hosts -> Hosts
	end.

escapeHost(Host)->
	re:replace(Host,"\\.","_",[global,{return,list}]).
