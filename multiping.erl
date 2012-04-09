#!/usr/bin/escript

-define(PING_TIMEOUT,9000).

main(["config"])->
	showConfig();
main([])->
	Hosts=getHosts(),
	forkGuards(Hosts),
	readFromGuards(Hosts);
main(Unknown)->
	io:format("Unknown parameters ~p",[Unknown]).

% Forks Guard processes commands for each host
forkGuards([]) ->
	[];
forkGuards([Host|HTail]) ->
	Master=self(),
	spawn(fun()->pingGuard(Host,Master) end),
	forkGuards(HTail).

% Reads messages from guards
readFromGuards([])->
	ok;
readFromGuards(HostList) ->
	receive
		{Host, result, RTT, Lost} ->
				printSingleVal(Host,RTT,Lost),
				NewHostList=lists:delete(Host,HostList),
				readFromGuards(NewHostList);
		{Host, timeout} ->
				printSingleVal(Host,timeout,timeout),
				NewHostList=lists:delete(Host,HostList),
				readFromGuards(NewHostList);
		Other ->
			io:format("#Got weird message : ~p\n",[Other]),
			readFromGuards(HostList)
	end.

% Process that runs single ping and guards time of the processing of it
pingGuard(Host,Master)->
	Command=lists:concat(["ping -nq ", getPingArgs(), " ", Host]),
	Port=open_port({spawn,Command},[]),
	receive
		{Port,{data,Data}} ->
				RTT=getRTTFromResponse(Data),
				Lost=getLostFromResponse(Data),
				Master ! {Host, result, RTT, Lost}
		after ?PING_TIMEOUT->
				port_close(Port),
				Master ! {Host, timeout}
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

