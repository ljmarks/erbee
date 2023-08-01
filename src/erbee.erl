-module(erbee).

-export([ decode/1
        , encode/1
        ]).

-export_type([bterm/0]).

-define(SUFFIX,      "e").
-define(PREFIX_INT,  "i").
-define(PREFIX_LIST, "l").
-define(PREFIX_DICT, "d").
-define(DELIM_BSTR,  ":").

-type dict() :: #{binary() => bterm()}.
-type bterm() :: binary() | dict() | integer() | [bterm()].
-type decode_result(Type) :: {Type, binary()}.

-spec decode(binary() | iolist()) -> {bterm(), binary()}.
decode(Bin) when is_binary(Bin) -> do_decode(Bin);
decode(IoList)                  -> decode(iolist_to_binary(IoList)).
  
-spec do_decode(binary()) -> {bterm(), binary()}.
do_decode(<<?PREFIX_DICT, Rest0/binary>>) ->
  decode_dict(Rest0);
do_decode(<<?PREFIX_INT, Rest/binary>>)  ->
  decode_int(Rest, []);
do_decode(<<?PREFIX_LIST, Rest0/binary>>) ->
  decode_list(Rest0);
do_decode(Bin) ->
  decode_bstr(Bin, []).

-spec decode_int(binary(), string()) -> decode_result(integer()).
decode_int(<<?SUFFIX, Rest/binary>>, Acc) ->
  {list_to_integer(lists:reverse(Acc)), Rest};
decode_int(<<Char, Rest/binary>>, Acc)    ->
  decode_int(Rest, [Char | Acc]).

-spec decode_list(binary()) -> decode_result([bterm()]).
decode_list(Bin) -> do_decode_list(Bin, []).

-spec do_decode_list(binary(), string()) -> decode_result([bterm()]).
do_decode_list(<<?SUFFIX, Rest/binary>>, Acc) ->
  {lists:reverse(Acc), Rest};
do_decode_list(Bin, Acc) ->
  {Elem, Rest} = decode(Bin),
  do_decode_list(Rest, [Elem | Acc]).

-spec decode_dict(binary()) -> decode_result(dict()).
decode_dict(Bin) -> do_decode_dict(Bin, #{}).

-spec do_decode_dict(binary(), dict()) -> decode_result(dict()).
do_decode_dict(<<?SUFFIX, Rest/binary>>, Acc) ->
  {Acc, Rest};
do_decode_dict(Bin, Acc) ->
  {Key, Rest0} = decode_bstr(Bin, []),
  {Val, Rest} = decode(Rest0),
  do_decode_dict(Rest, Acc#{Key => Val}).

-spec decode_bstr(binary(), string()) -> decode_result(binary()).
decode_bstr(<<?DELIM_BSTR, Rest0/binary>>, Acc) ->
  Len = list_to_integer(lists:reverse(Acc)),
  <<BStr:Len/binary, Rest/binary>> = Rest0,
  {BStr, Rest};
decode_bstr(<<Char, Rest/binary>>, Acc) ->
  decode_bstr(Rest, [Char | Acc]).

-spec encode(bterm()) -> binary().
encode(Term) when is_list(Term)    ->
  encode_list(Term);
encode(Term) when is_integer(Term) ->
  IntBin = integer_to_binary(Term, 10),
  <<?PREFIX_INT, IntBin/binary, ?SUFFIX>>;
encode(Term) when is_map(Term)     ->
  encode_map(Term);
encode(Term) when is_binary(Term)  ->
  LenBin = integer_to_binary(byte_size(Term), 10),
  <<LenBin/binary, ?DELIM_BSTR, Term/binary>>.

-spec encode_map(dict()) -> binary().
encode_map(Map) ->
  Kvs = lists:keysort(1, maps:to_list(Map)),
  do_encode_map(Kvs, <<?PREFIX_DICT>>).

-spec do_encode_map([{binary(), bterm()}], binary()) -> binary().
do_encode_map([], Acc)                                      -> <<Acc/binary, ?SUFFIX>>;
do_encode_map([{Key, Val} | Tail], Acc) when is_binary(Key) ->
  KeyBin = encode(Key),
  ValBin = encode(Val),
  do_encode_map(Tail, <<Acc/binary, KeyBin/binary, ValBin/binary>>).

-spec encode_list([bterm()]) -> binary().
encode_list(List) -> do_encode_list(List, <<?PREFIX_LIST>>).

-spec do_encode_list([bterm()], binary()) -> binary().
do_encode_list([], Acc)            -> <<Acc/binary, ?SUFFIX>>;
do_encode_list([Elem | Tail], Acc) ->
  ElemBin = encode(Elem),
  do_encode_list(Tail, <<Acc/binary, ElemBin/binary>>).
