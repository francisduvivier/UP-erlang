%Francis Duvivier - s0215207
-module(tileSuperVisor).
-export ([tileSVMain/0]).
-import (glob, [regformat/1,registerName/2]).

tileSVMain() ->
	DeadTiles=getDeadTiles(16),
	if
		DeadTiles/=[] ->
				reviveDeadTiles(DeadTiles,getLastState());
		true ->
			ok
	end,
	tileSVMain() 
	.
reviveDeadTiles(DeadTiles,LastState)->
	lists:map(
		fun(DeadTile)->
			reviveDeadTile(DeadTile, LastState)	
		end,
		DeadTiles).

reviveDeadTile(DeadTile, LastState) ->
	LastVal=erlang:element(DeadTile,LastState),
	debug:debug("TSVR Reviving ~p with val ~p.~n",[DeadTile,LastVal]),
	DeadTilePID=
		spawn(
			fun() ->
				tile:tilemain(DeadTile,LastVal) 
			end),
	registerName(regformat(DeadTile),DeadTilePID).

getLastState() ->
	tileIK!{getLastState,self()},
	receive 
		{lastState,CurrState} ->
			CurrState
	end.

getDeadTiles(StartID) ->
	getDeadTiles(StartID,[]).

getDeadTiles(CurrId, CurrList) ->
	if
		CurrId==0 ->
			CurrList;
		true ->
			IsDead=isDead(CurrId),
			if
				IsDead ->
					getDeadTiles(CurrId-1,[CurrId|CurrList]);
				true ->
					getDeadTiles(CurrId-1,CurrList)
			end
	end.

isDead(Id) ->
  	whereis(regformat(Id))==undefined.
