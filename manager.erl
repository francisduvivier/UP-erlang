%Francis Duvivier - s0215207
-module(manager).

-export([manage/0]).

manage() ->
% debug:debug("Hi there, debug is working and it is called in manage/0"), %% to delete, this would work.
	%Francis Duvivier - Changed
	spawnTiles(16),
	startInfoKeeper(),
	startSuperVisor(),
	startConcMgr(),
	%End Changed
	manageloop().
	
spawnTiles(0) ->ok;
spawnTiles(TileNb) ->
	TPID=spawn(fun()-> tile:tilemain(TileNb) end),
	glob:registerName(glob:regformat(TileNb), TPID),
	spawnTiles(TileNb-1).
% when receiving the message $senddata, spawn a collector and a broadcaster for the collection of the data
%  from the tiles. Then, once the $Data is collected, inform the lifeguard and the gui

%Francis Duvivier - Changed
startInfoKeeper() ->
	PID=spawn(fun tileInfoKeeper:startInfoKeeper/0),
	glob:registerName(tileIK, PID).

startSuperVisor() ->
	PID=spawn(fun tileSuperVisor:tileSVMain/0),
	glob:registerName(tileSV, PID).

startConcMgr() ->
	PID=spawn(fun concurrencyMgr:startConcMgr/0),
	glob:registerName(concMgr, PID).

getBaseTuple() ->
	{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}.
%End Changed

manageloop() ->
	receive
		up ->
			Tmp = [1,2,3,4],
			sendDir(Tmp,up);
		dn ->
			Tmp = [13,14,15,16],
			sendDir(Tmp,dn);
		lx ->
			Tmp = [1,5,9,13],
			sendDir(Tmp,lx);
		rx ->
			Tmp = [4,8,12,16],
			sendDir(Tmp,rx);
		sendData ->
			Basetuple = getBaseTuple(),
			%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
			% this is the instruction mentioned in the text %
			%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
			waitTillFinished(),
			%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
			% this is the instruction mentioned in the text %
			%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
			PidCollector = spawn( fun() -> collect( 0, Basetuple ) end),
			register( collector, PidCollector ),
			spawn( fun() -> broadcaster( 16, {yourValue, collector} ) end);	
		{collectedData, TupleData} ->
			%Francis Duvivier - Changed
			tileIK!{newTileData,TupleData},
			ListData = randomiseatile(TupleData),
			%Francis Duvivier - Changed
			tileIK!{newTileData,erlang:list_to_tuple(ListData)},
			%End Changed
			gui ! {values, ListData}
	end,
	manageloop().

sendDir(Ids,Dir) ->
	concMgr!reset,
	lists:map(fun(X) -> glob:regformat(X) ! Dir end, Ids).

waitTillFinished()->
	debug:debug("Starting to wait.~n",[]),
	concMgr!sendWhenFinished,
	receive
		{allFinished,true} ->
			debug:debug("Waiting finished.~n",[]),
			ok
	end.

% takes a tuple of data in input and returns it in a list format
% with two elements that were at 0 now randomised at 2
randomiseatile( Tuple )->
	{A1,A2,A3} = now(),
    random:seed(A1, A2, A3),
	case glob:zeroesintuple(Tuple) of
		0 ->
			Tu = Tuple;
		_ ->
			C1 = getCand(0, Tuple),
			V1 = 2,
			debug:debug("MANAGER: radomised in ~p.~n",[C1]),
			glob:regformat(C1) ! {setvalue, V1, false},
			Tu = erlang:setelement(C1,Tuple,V1)
	end,
	erlang:tuple_to_list(Tu).

% returns a number from 1 to 16 different from $Oth
	% such that its value in $T is 0, i.e. $return can be initialised at random
getCand( Oth , T)->
	C = random:uniform(16),
	case C of
		Oth -> getCand(Oth, T);
		_ ->
			case erlang:element(C, T) of
				0 -> C;
				_ -> getCand(Oth, T)
			end
	end.

% collects 16 numbes in $T, then returns the related tuple
%	$T is a tuple of length 16
collect( N , T) ->
	case N of
		16 -> 
			manager ! {collectedData, T};
		Num ->
			receive
				{tilevalue, Id, Value, _} ->
					collect( Num+1, erlang:setelement(Id, T, Value))
			end
	end.

% Sends message $Mess to all tiles
broadcaster( 0, _ )->
	ok;
broadcaster( N, Mess ) when N < 17 -> 
	try glob:regformat(N) ! Mess of
		_ -> 
			%debug:debug("broadcasting to ~p.~n",[N]),
			ok
	catch
		_:F -> 
			debug:debug("BROADCASTER: cannot commmunicate to ~p. Error ~p.~n",[N,F])
	end,
	broadcaster( N-1, Mess ).
