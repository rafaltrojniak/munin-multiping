#!/usr/bin/escript

main(["config"])->
	showConfig();
main([])->
	Pids=forkPings(getHosts()),
	readResults(Pids);
main(Unknown)->
	io:format("Unknown parameters ~p",[Unknown]).



% Forks ping command for each host
forkPings([]) ->
	[];
forkPings([Host|HTail]) ->
	Command=lists:concat(["ping -nq ", getPingArgs(), " ", Host]),
	Pid=open_port({spawn,Command},[]),
	[{Host,Pid}|forkPings(HTail)].

% Parses an reads results
readResults([])->
	ok;
readResults(PidList) ->
	receive
		{Pid,{data,Data}} ->
			case lists:keyfind(Pid,2,PidList) of
				false -> readResults(PidList);
				{Host,Pid} ->
					RTT=getRTTFromResponse(Data),
					Lost=getLostFromResponse(Data),
					printSingleVal(Host,RTT,Lost),
					NewPidList=lists:keydelete(Pid,2,PidList),
					readResults(NewPidList)
			end
	end.


%% Munin protocol helpers

% Prints configuration block
showConfig()->
	io:format("graph_title Multiping\n",[]),
	Hosts=getHosts(),
	lists:foreach(fun(Host)->printSingleConfig(Host) end,Hosts),
	ok.

% Prints configuration for single host
printSingleConfig(Host) ->
	EHost=escapeHost(Host),
	io:format("~s_rtt.label ~s RTT\n",[EHost,Host]),
	io:format("~s_lost.label ~s Lost packets\n",[EHost,Host]),
	ok.

% Prints vlues for single host
printSingleVal(Host,RTT,Lost)->
	EHost=escapeHost(Host),
	io:format("~s_rtt.value ~s\n",[EHost,RTT]),
	io:format("~s_lost.value  ~s\n",[EHost,Lost]),
	ok.

% Esape string to use as field name
escapeHost(Host)->
	re:replace(Host,"\\.","_",[global,{return,list}]).

%% Ping command output scrapers

% Fetches Round-Trip-Time
getRTTFromResponse(Data)->
	case re:run(Data,"min/avg/max.*\\s\\d+(?:\\.\\d+)?/(\\d+(?:\\.\\d+)?)/\\d+(?:\\.\\d+)?",[{capture,all_but_first,list}]) of
		{match,[Val]} -> Val;
		_ -> nomatch
	end.

% Fetches count of lost packets
getLostFromResponse(Data)->
	case re:run(Data,"received, (\\d+)% packet loss, time",[{capture,all_but_first,list}]) of
		{match,[Val]} -> Val;
		_ -> nomatch
	end.

%% ENV Readings

% Returns host list to ping
getHosts()->
	case os:getenv("host") of 
		false -> [];
		Hosts -> string:tokens(Hosts," \t")
	end.

% Returns ping command args
getPingArgs()->
	case os:getenv("ping_args") of 
		false -> "-c 5 ";
		Hosts -> Hosts
	end.

