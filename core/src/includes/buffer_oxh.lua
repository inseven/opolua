return [[
rem Buffer.oxh
rem
rem Copyright (c) 1997-2002 Symbian Ltd. All rights reserved.
rem

CONST KOpxBufferUid&=&10004EC9
CONST KOpxBufferVersion%=$600

CONST KBufferNoFoldOrCollate&=0
CONST KBufferFold&=1
CONST KBufferCollate&=2

CONST KBufferNotFound&=-1

DECLARE OPX BUFFER,KOpxBufferUid&,KOpxBufferVersion%
    BufferCopy:(aTargetBuffer&, aSourceBuffer&, aLength&) :1
    BufferFill:(aBuffer&, aLength&, aChar%) :2
    BufferAsString$:(aSourceBuffer&, aLength&) :3
    BufferFromString&:(aTargetBuffer&, aLength&, aSource$) :4
    BufferMatch&:(aBuffer&, aLength&, aPattern$, aFoldMode&) :5
    BufferFind&:(aBuffer&, aLength&, aString$, aFoldMode&) :6
    BufferLocate&:(aBuffer&, aLength&, aChar%, aFoldMode&) :7
    BufferLocateReverse&:(aBuffer&, aLength&, aChar%, aFoldMode&) :8
END DECLARE
]]