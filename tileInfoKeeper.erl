%Francis Duvivier - s0215207
-module(tileInfoKeeper).
-export ([startInfoKeeper/0]).
startInfoKeeper()->
	tileInfoLoop({0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}).
	
tileInfoLoop(CurrState) ->
	receive
		{newTileData, TupleData} ->
			debug:debug("we got info, {~p,~p,~p,~p,~p,~p,~p,~p,~p,~p,~p,~p,~p,~p,~p,~p}  ~n",erlang:tuple_to_list(TupleData))	,
			tileInfoLoop(TupleData);
		{getLastState,Repl} ->
			Repl!{lastState,CurrState},
			tileInfoLoop(CurrState)
	end.