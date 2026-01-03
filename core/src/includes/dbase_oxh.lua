return [[
rem DBase.oxh
rem
rem Copyright (c) 1997-2002 Symbian Ltd. All rights reserved.
rem

CONST KUidOpxDBase&=&1000025B
CONST KOpxDBaseVersion%=$100

CONST KDbCompareNormal&=0
CONST KDbCompareFolded&=1
CONST KDbCompareCollated&=2
CONST KDbAscending&=1
CONST KDbDescending&=0

DECLARE OPX DBASE,KUidOpxDBase&,KOpxDBaseVersion%
    DbAddField:(keyPtr&,fieldName$,order&) :1
    DbAddFieldTrunc:(keyPtr&,fieldName$,order&,trunc&) :2
    DbCreateIndex:(index$,keyPtr&,dbase$,table$) :3
    DbDeleteKey:(keyPtr&) :4
    DbDropIndex:(index$,dbase$,table$) :5
    DbGetFieldCount&:(dbase$,table$) :6
    DbGetFieldName$:(dbase$,table$,fieldNum&) :7
    DbGetFieldType&:(dbase$,table$,fieldNum&) :8
    DbIsDamaged&:(dbase$) :9
    DbIsUnique&:(keyPtr&) :10
    DbMakeUnique:(keyPtr&) :11
    DbNewKey&: :12
    DbRecover:(dbase$) :13
    DbSetComparison:(KeyPtr&,comp&) :14
END DECLARE
]]
