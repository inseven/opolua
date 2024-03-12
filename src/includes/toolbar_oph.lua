return [[
rem Toolbar.oph
rem Header file for OPL's toolbar
rem Copyright (c) 1997-1998 Symbian Ltd. All rights reserved.

rem Public procedures
external TBarLink:(appLink$)
external TBarInit:(title$,scrW%,scrH%)
external TBarInitC:(title$,scrW%,scrH%,winMode%)
external TBarInitNonStd:(name$,scrW%,scrH%,width%)
external TBarSetTitle:(name$)
external TBarButt:(shortCut$,pos%,text$,state%,bit&,mask&,flags%)
external TBarOffer%:(winId&,ptrType&,ptrX&,ptrY&)
external TBarLatch:(comp%)
external TBarShow:
external TBarHide:
external TBarColor:(fgR%,fgG%,fgB%,bgR%,bgG%,bgB%)

rem The following are global toolbar variables usable by Opl programs
rem or libraries: usable after toolbar initialisation:
rem     TbWidth%            the pixel width of the toolbar
rem     TbVis%              -1 if visible and otherwise 0
rem     TbMenuSym%      the current 'Show toolbar' menu symbol (to be ORed with shortcut letter)

rem Flags for toolbar buttons
const KTbFlgCmdOnPtrDown%=$01

rem The order and values of the following are significant so don't change without due care
const KTbFlgLatchStart%=$12     rem start of latchable set
const KTbFlgLatchMiddle%=$22    rem middle of latchable set
const KTbFlgLatchEnd%=$32           rem end of latchable set
const KTbFlgLatched%=$04            rem set for current latched item in set

rem End of Toolbar.oph
]]
