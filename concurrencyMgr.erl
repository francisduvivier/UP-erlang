%Francis Duvivier - s0215207
-module(concurrencyMgr).

-export ([startConcMgr/0]).

startConcMgr()->
	receiveLoop(getTrueTuple(),false).

receiveLoop(CurrState, SendWhenFinished) ->
	AllFinished=allFinished(CurrState),
	if
		SendWhenFinished and AllFinished ->
			debug:debug("Sending allFinished.~n",[]),
			manager!{allFinished,true},
			receiveLoop(CurrState,false);
		true ->
			receive
				reset ->
					receiveLoop(getBaseTuple(),SendWhenFinished);
				sendWhenFinished ->
					receiveLoop(CurrState,true);
				{finished, Id} ->
					debug:debug("FNSH: ~p, ",[Id]),
					receiveLoop(erlang:setelement(Id,CurrState,true),SendWhenFinished)
			end
	end.

allFinished(Tuple) ->
	not(lists:member(false,erlang:tuple_to_list(Tuple))).

getBaseTuple() ->
{false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false}.
getTrueTuple() ->
{true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true}.