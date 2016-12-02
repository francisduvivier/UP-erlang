%Francis Duvivier - s0215207
-module(tile).
-export([tilemain/1,tilemain/2]).
-import (glob, [regformat/1]).
-import (lists, [append/2]).
tilemain( Id ) ->
	tilemain(Id, 0).

tilemain( Id, Value ) ->
	tilelife(Id,Value, false).


%%%%%%%%%%%%%%%%%
% fill this out %
%%%%%%%%%%%%%%%%%
tilelife(Id, Value, Merged) ->
	receive
		die ->
			debug:debug("I, ~p, die.~n",[Id]),
			exit(killed);
		Dir when (Dir==up)or(Dir==dn)or(Dir==lx)or(Dir==rx) ->
			IsMoved=moveValueToNext(Value, Id, Dir),			
			forwardInstruction(Dir, Id),
			concMgr!{finished,Id}, %We inform the concurrency manager that this tile is finished.
			callTilelife(IsMoved, Id, Value);
		{yourValue, Repl} ->
			Repl ! {tilevalue, Id, Value, Merged},
			tilelife(Id, Value, Merged);
		{setvalue, FutrVal, FutrMerg} ->
			tilelife(Id, FutrVal, FutrMerg)
	end.

moveValueToNext(Value,Id,Dir)->
	%\/The first thing we do when we receive a direction is 			\/
	%\/calcuting where to send the value of this tile to, and sending it\/		
	if 	
		Value==0 -> 
			false;
		true ->
			%\/We get the info for the tuple that this value will go to\/
			{NextId, NextVal, NextMerged}=getNextTuple({Id, Value},makeOthersList(Id, Dir)),
			if
				NextId==Id -> 
					false;
				true ->
					%\/We send that info to the corresponding Id\/ 
					regformat(NextId)!{setvalue, NextVal, NextMerged},
					true
			end
	end.

forwardInstruction(Dir, Id) ->
	%\/We forward the Direction message to the tuple in the other direction(if there is one)\/ 
	ForwardId=getNextId(getOppDir(Dir),Id),
				%\/We check whether there is valid tile in the other direction\/
	NotOOB=not(oob(Id,ForwardId)), 
	if 
		NotOOB ->
			regformat(ForwardId)!Dir;
		true -> ok
	end.

callTilelife(IsMoved, Id, Value) ->
	%\/We call tilelife again to keep the tile alive, 			\/
	%\/if it has not sent its value to another tile, 			\/
	%\/then the value stays the same, otherwise it changes to 0 \/	
	if
		IsMoved ->
			tilelife(Id, 0, false);
		true -> 
			tilelife(Id, Value, false)

	end.

getOppDir(Dir)->
	case Dir of
		up ->
			dn;
		dn ->
			up;
		rx ->
			lx;
		lx ->
			rx
	end.

getNextId(Dir,Id) ->
	case Dir of
		up ->
			Id-4;
		dn ->
			Id+4;
		rx ->
			Id+1;
		lx ->
			Id-1
	end.

oob(Prev, Next)->
	if
        ((Next<1) or (16<Next)) ->
            true;
        abs(Prev-Next)==1 ->
        	SameRow=sameRow(Next,Prev),
	        if 
	        	not(SameRow)->
	        		true;
	        	true -> 
	        		false
	        end;
        true ->
            false
    end.

%\/Makes a list by recursively changing the startId with the changefunc \/
%\/and only stopping recursion when stopfunc returns true.\/
%\/The startId is not included in the list.\/
makeList(StartId,ChangeFunc, StopFunc)->
			makeList([],StartId,ChangeFunc, StopFunc).

makeList(CurrList,PrevId,ChangeFunc,StopFunc)->
	Id=ChangeFunc(PrevId),
	InvalidId=StopFunc(PrevId,Id),
	if
		InvalidId  -> 
			CurrList;
		true ->
			makeList(append(CurrList,[Id]),Id,ChangeFunc,StopFunc)
	end.


getNextTuple({ThisId,ThisVal},TList)->
	case TList of
		[] ->
			{ThisId,ThisVal,false};
		_ ->
			getNextTuple(
				{ThisId,ThisVal},
				TList,
				{-1,-1}
				)
	end.

%calculates about where to and which info to send. It needs the previous info in case the FirstVal is not 0 and not the same either.
%need ThisId and ThisVal for being able to compare and in case none of the next tuples should be changed.
getNextTuple({ThisId,ThisVal},[FrstId|Rest], {PrevId,PrevVal})->
	{FrstVal,FrstMerged}=receiveInfo(FrstId),

	case FrstVal of
		0 ->
			if
				Rest/=[]->
					getNextTuple({ThisId,ThisVal},Rest, {FrstId,ThisVal});
				true ->
					{FrstId,ThisVal,false}
			end;
		ThisVal when not(FrstMerged)->
			{FrstId,FrstVal*2,true};
		_ -> 
			if
				PrevId/=-1 ->
					{PrevId,PrevVal,false};
				true ->
					{ThisId,ThisVal,false}
			end
	end.

receiveInfo(OtherId) ->
	regformat(OtherId)!{yourValue, self()},
	receive 
		{tilevalue, OtherId, ReplValue, Merged} ->
			{ReplValue,Merged}
	end.


sameRow(Next,Prev)->
	trunc((Next-1)/4) == trunc((Prev-1)/4).

makeOthersList(CurrId,Dir)->
	makeList(
		CurrId,
		fun(Id)-> getNextId(Dir,Id) end,
		fun oob/2
	).