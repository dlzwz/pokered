; function to draw various text boxes
DisplayTextBoxID_::
	ld a, [wTextBoxID]
	cp TWO_OPTION_MENU
	jp z, DisplayTwoOptionMenu
	ld c, a
	ld hl, TextBoxFunctionTable
	ld de, 3
	call SearchTextBoxTable
	jr c, .functionTableMatch
	ld hl, TextBoxCoordTable
	ld de, 5
	call SearchTextBoxTable
	jr c, .coordTableMatch
	ld hl, TextBoxTextAndCoordTable
	ld de, 9
	call SearchTextBoxTable
	jr c, .textAndCoordTableMatch
.done
	ret
.functionTableMatch
	ld a, [hli]
	ld h, [hl]
	ld l, a ; hl = address of function
	ld de, .done
	push de
	jp hl ; jump to the function
.coordTableMatch
	call GetTextBoxIDCoords
	call GetAddressOfScreenCoords
	call TextBoxBorder
	ret
.textAndCoordTableMatch
	call GetTextBoxIDCoords
	push hl
	call GetAddressOfScreenCoords
	call TextBoxBorder
	pop hl
	call GetTextBoxIDText
	ld a, [wStatusFlags5]
	push af
	ld a, [wStatusFlags5]
	set BIT_NO_TEXT_DELAY, a
	ld [wStatusFlags5], a
	call PlaceString
	pop af
	ld [wStatusFlags5], a
	call UpdateSprites
	ret

; function to search a table terminated with $ff for a byte matching c in increments of de
; sets carry flag if a match is found and clears carry flag if not
SearchTextBoxTable:
	dec de
.loop
	ld a, [hli]
	cp $ff
	jr z, .notFound
	cp c
	jr z, .found
	add hl, de
	jr .loop
.found
	scf
.notFound
	ret

; function to load coordinates from the TextBoxCoordTable or the TextBoxTextAndCoordTable
; INPUT:
; hl = address of coordinates
; OUTPUT:
; b = height
; c = width
; d = row of upper left corner
; e = column of upper left corner
GetTextBoxIDCoords:
	ld a, [hli] ; column of upper left corner
	ld e, a
	ld a, [hli] ; row of upper left corner
	ld d, a
	ld a, [hli] ; column of lower right corner
	sub e
	dec a
	ld c, a     ; c = width
	ld a, [hli] ; row of lower right corner
	sub d
	dec a
	ld b, a     ; b = height
	ret

; function to load a text address and text coordinates from the TextBoxTextAndCoordTable
GetTextBoxIDText:
	ld a, [hli]
	ld e, a
	ld a, [hli]
	ld d, a ; de = address of text
	push de ; save text address
	ld a, [hli]
	ld e, a ; column of upper left corner of text
	ld a, [hl]
	ld d, a ; row of upper left corner of text
	call GetAddressOfScreenCoords
	pop de ; restore text address
	ret

; function to point hl to the screen coordinates
; INPUT:
; d = row
; e = column
; OUTPUT:
; hl = address of upper left corner of text box
GetAddressOfScreenCoords:
	push bc
	hlcoord 0, 0
	ld bc, 20
.loop ; loop to add d rows to the base address
	ld a, d
	and a
	jr z, .addedRows
	add hl, bc
	dec d
	jr .loop
.addedRows
	pop bc
	add hl, de
	ret

INCLUDE "data/text_boxes.asm"

DisplayMoneyBox:
	ld hl, wStatusFlags5
	set BIT_NO_TEXT_DELAY, [hl]
	ld a, MONEY_BOX_TEMPLATE
	ld [wTextBoxID], a
	call DisplayTextBoxID
	hlcoord 13, 1
	ld b, 1
	ld c, 6
	call ClearScreenArea
	hlcoord 12, 1
	ld de, wPlayerMoney
	ld c, 3 | LEADING_ZEROES | MONEY_SIGN
	call PrintBCDNumber
	ld hl, wStatusFlags5
	res BIT_NO_TEXT_DELAY, [hl]
	ret

CurrencyString:
	db "      ¥@"

DoBuySellQuitMenu:
	ld a, [wStatusFlags5]
	set BIT_NO_TEXT_DELAY, a
	ld [wStatusFlags5], a
	xor a
	ld [wChosenMenuItem], a
	ld a, BUY_SELL_QUIT_MENU_TEMPLATE
	ld [wTextBoxID], a
	call DisplayTextBoxID
	ld a, PAD_A | PAD_B
	ld [wMenuWatchedKeys], a
	ld a, $2
	ld [wMaxMenuItem], a
	ld a, $1
	ld [wTopMenuItemY], a
	ld a, $1
	ld [wTopMenuItemX], a
	xor a
	ld [wCurrentMenuItem], a
	ld [wLastMenuItem], a
	ld [wMenuWatchMovingOutOfBounds], a
	ld a, [wStatusFlags5]
	res BIT_NO_TEXT_DELAY, a
	ld [wStatusFlags5], a
	call HandleMenuInput
	call PlaceUnfilledArrowMenuCursor
	bit B_PAD_A, a
	jr nz, .pressedA
	bit B_PAD_B, a ; always true since only A/B are watched
	jr z, .pressedA
	ld a, CANCELLED_MENU
	ld [wMenuExitMethod], a
	jr .quit
.pressedA
	ld a, CHOSE_MENU_ITEM
	ld [wMenuExitMethod], a
	ld a, [wCurrentMenuItem]
	ld [wChosenMenuItem], a
	ld b, a
	ld a, [wMaxMenuItem]
	cp b
	jr z, .quit
	ret
.quit
	ld a, CANCELLED_MENU
	ld [wMenuExitMethod], a
	ld a, [wCurrentMenuItem]
	ld [wChosenMenuItem], a
	scf
	ret

; displays a menu with two options to choose from
; b = Y of upper left corner of text region
; c = X of upper left corner of text region
; hl = address where the text box border should be drawn
DisplayTwoOptionMenu:
	push hl
	ld a, [wStatusFlags5]
	set BIT_NO_TEXT_DELAY, a
	ld [wStatusFlags5], a

; pointless because both values are overwritten before they are read
	xor a
	ld [wChosenMenuItem], a
	ld [wMenuExitMethod], a

	ld a, PAD_A | PAD_B
	ld [wMenuWatchedKeys], a
	ld a, $1
	ld [wMaxMenuItem], a
	ld a, b
	ld [wTopMenuItemY], a
	ld a, c
	ld [wTopMenuItemX], a
	xor a
	ld [wLastMenuItem], a
	ld [wMenuWatchMovingOutOfBounds], a
	push hl
	ld hl, wTwoOptionMenuID
	bit BIT_SECOND_MENU_OPTION_DEFAULT, [hl]
	res BIT_SECOND_MENU_OPTION_DEFAULT, [hl]
	jr z, .storeCurrentMenuItem
	inc a
.storeCurrentMenuItem
	ld [wCurrentMenuItem], a
	pop hl
	push hl
	push hl
	call TwoOptionMenu_SaveScreenTiles
	ld a, [wTwoOptionMenuID]
	ld hl, TwoOptionMenuStrings
	ld e, a
	ld d, $0
	ld a, $5
.menuStringLoop
	add hl, de
	dec a
	jr nz, .menuStringLoop
	ld a, [hli]
	ld c, a
	ld a, [hli]
	ld b, a
	ld e, l
	ld d, h
	pop hl
	push de
	ld a, [wTwoOptionMenuID]
	cp TRADE_CANCEL_MENU
	jr nz, .notTradeCancelMenu
	call CableClub_TextBoxBorder
	jr .afterTextBoxBorder
.notTradeCancelMenu
	call TextBoxBorder
.afterTextBoxBorder
	call UpdateSprites
	pop hl
	ld a, [hli]
	and a ; put blank line before first menu item?
	ld bc, 20 + 2
	jr z, .noBlankLine
	ld bc, 2 * 20 + 2
.noBlankLine
	ld a, [hli]
	ld e, a
	ld a, [hli]
	ld d, a
	pop hl
	add hl, bc
	call PlaceString
	ld hl, wStatusFlags5
	res BIT_NO_TEXT_DELAY, [hl]
	ld a, [wTwoOptionMenuID]
	cp NO_YES_MENU
	jr nz, .notNoYesMenu
; No/Yes menu
; this menu type ignores the B button
; it only seems to be used when confirming the deletion of a save file
	xor a
	ld [wTwoOptionMenuID], a
	ld a, [wMiscFlags]
	push af
	push hl
	ld hl, wMiscFlags
	bit BIT_NO_MENU_BUTTON_SOUND, [hl]
	set BIT_NO_MENU_BUTTON_SOUND, [hl]
	pop hl
.noYesMenuInputLoop
	call HandleMenuInput
	bit B_PAD_B, a
	jr nz, .noYesMenuInputLoop ; try again if B was not pressed
	pop af
	pop hl
	ld [wMiscFlags], a
	ld a, SFX_PRESS_AB
	call PlaySound
	jr .pressedAButton
.notNoYesMenu
	xor a
	ld [wTwoOptionMenuID], a
	call HandleMenuInput
	pop hl
	bit B_PAD_B, a
	jr nz, .choseSecondMenuItem ; automatically choose the second option if B is pressed
.pressedAButton
	ld a, [wCurrentMenuItem]
	ld [wChosenMenuItem], a
	and a
	jr nz, .choseSecondMenuItem
; chose first menu item
	ld a, CHOSE_FIRST_ITEM
	ld [wMenuExitMethod], a
	ld c, 15
	call DelayFrames
	call TwoOptionMenu_RestoreScreenTiles
	and a
	ret
.choseSecondMenuItem
	ld a, 1
	ld [wCurrentMenuItem], a
	ld [wChosenMenuItem], a
	ld a, CHOSE_SECOND_ITEM
	ld [wMenuExitMethod], a
	ld c, 15
	call DelayFrames
	call TwoOptionMenu_RestoreScreenTiles
	scf
	ret

; Some of the wider/taller two option menus will not have the screen areas
; they cover be fully saved/restored by the two functions below.
; The bottom and right edges of the menu may remain after the function returns.

TwoOptionMenu_SaveScreenTiles:
	ld de, wBuffer
	lb bc, 5, 6
.loop
	ld a, [hli]
	ld [de], a
	inc de
	dec c
	jr nz, .loop
	push bc
	ld bc, SCREEN_WIDTH - 6
	add hl, bc
	pop bc
	ld c, $6
	dec b
	jr nz, .loop
	ret

TwoOptionMenu_RestoreScreenTiles:
	ld de, wBuffer
	lb bc, 5, 6
.loop
	ld a, [de]
	inc de
	ld [hli], a
	dec c
	jr nz, .loop
	push bc
	ld bc, SCREEN_WIDTH - 6
	add hl, bc
	pop bc
	ld c, 6
	dec b
	jr nz, .loop
	call UpdateSprites
	ret

INCLUDE "data/yes_no_menu_strings.asm"

DisplayFieldMoveMonMenu:
	xor a
	ld hl, wFieldMoves
	ld [hli], a ; wFieldMoves
	ld [hli], a ; wFieldMoves + 1
	ld [hli], a ; wFieldMoves + 2
	ld [hli], a ; wFieldMoves + 3
	ld [hli], a ; wNumFieldMoves
	ld [hl], 12 ; wFieldMovesLeftmostXCoord
	call GetMonFieldMoves
	ld a, [wNumFieldMoves]
	and a
	jr nz, .fieldMovesExist

; no field moves
	hlcoord 11, 11
	ld b, 5
	ld c, 7
	call TextBoxBorder
	call UpdateSprites
	ld a, 12
	ldh [hFieldMoveMonMenuTopMenuItemX], a
	hlcoord 13, 12
	ld de, PokemonMenuEntries
	jp PlaceString

.fieldMovesExist
	push af

; Calculate the text box position and dimensions based on the leftmost X coord
; of the field move names before adjusting for the number of field moves.
	hlcoord 0, 11
	ld a, [wFieldMovesLeftmostXCoord]
	dec a
	ld e, a
	ld d, 0
	add hl, de
	ld b, 5
	ld a, 18
	sub e
	ld c, a
	pop af

; For each field move, move the top of the text box up 2 rows while the leaving
; the bottom of the text box at the bottom of the screen.
	ld de, -SCREEN_WIDTH * 2
.textBoxHeightLoop
	add hl, de
	inc b
	inc b
	dec a
	jr nz, .textBoxHeightLoop

; Make space for an extra blank row above the top field move.
	ld de, -SCREEN_WIDTH
	add hl, de
	inc b

	call TextBoxBorder
	call UpdateSprites

; Calculate the position of the first field move name to print.
	hlcoord 0, 12
	ld a, [wFieldMovesLeftmostXCoord]
	inc a
	ld e, a
	ld d, 0
	add hl, de
	ld de, -SCREEN_WIDTH * 2
	ld a, [wNumFieldMoves]
.calcFirstFieldMoveYLoop
	add hl, de
	dec a
	jr nz, .calcFirstFieldMoveYLoop

	xor a
	ld [wNumFieldMoves], a
	ld de, wFieldMoves
.printNamesLoop
	push hl
	ld hl, FieldMoveNames
	ld a, [de]
	and a
	jr z, .donePrintingNames
	inc de
	ld b, a ; index of name
.skipNamesLoop ; skip past names before the name we want
	dec b
	jr z, .reachedName
.skipNameLoop ; skip past current name
	ld a, [hli]
	cp '@'
	jr nz, .skipNameLoop
	jr .skipNamesLoop
.reachedName
	ld b, h
	ld c, l
	pop hl
	push de
	ld d, b
	ld e, c
	call PlaceString
	ld bc, SCREEN_WIDTH * 2
	add hl, bc
	pop de
	jr .printNamesLoop

.donePrintingNames
	pop hl
	ld a, [wFieldMovesLeftmostXCoord]
	ldh [hFieldMoveMonMenuTopMenuItemX], a
	hlcoord 0, 12
	ld a, [wFieldMovesLeftmostXCoord]
	inc a
	ld e, a
	ld d, 0
	add hl, de
	ld de, PokemonMenuEntries
	jp PlaceString

INCLUDE "data/moves/field_move_names.asm"

PokemonMenuEntries:
	db   "STATS"
	next "SWITCH"
	next "CANCEL@"

; Check if the Pokemon in [wWhichPokemon] can learn move in register b
; Returns: carry clear if can learn, carry set if cannot learn
; Preserves: bc, de, hl
CanLearnFieldMove:
	push bc
	push de
	push hl
	; Get Pokemon species
	ld a, [wWhichPokemon]
	ld hl, wPartySpecies
	ld e, a
	ld d, 0
	add hl, de
	ld a, [hl]
	ld [wCurPartySpecies], a
	ld [wCurSpecies], a
	; Only check the 5 Gen 1 HMs
	ld a, b
	cp CUT
	jr z, .checkHM
	cp FLY
	jr z, .checkHM
	cp SURF
	jr z, .checkHM
	cp STRENGTH
	jr z, .checkHM
	cp FLASH
	jr z, .checkHM
	; Not a Gen 1 HM, check level-up moves
	jr .checkLevelUp
.checkHM
	; For HMs, manually check the tmhm bitfield
	; First, load the Pokemon's base stats
	push bc
	call GetMonHeader
	pop bc
	; Now wMonHLearnset contains the tmhm bitfield
	; Find which bit corresponds to this HM
	; b = move ID, need to find its _TMNUM value
	ld a, b
	cp CUT
	jr nz, .notCut
	ld c, 50 ; CUT_TMNUM - 1 = 51 - 1 = 50
	jr .testBit
.notCut
	cp FLY
	jr nz, .notFly
	; Special case: Charizard can use FLY in the field menu (Yellow version behavior)
	ld a, [wCurPartySpecies]
	cp CHARIZARD
	jr nz, .notCharizardFly
	; This is Charizard checking FLY - always allow
	jr .canLearn
.notCharizardFly
	ld c, 51 ; FLY_TMNUM - 1 = 52 - 1 = 51
	jr .testBit
.notFly
	cp SURF
	jr nz, .notSurf
	ld c, 52 ; SURF_TMNUM - 1 = 53 - 1 = 52
	jr .testBit
.notSurf
	cp STRENGTH
	jr nz, .notStrength
	ld c, 53 ; STRENGTH_TMNUM - 1 = 54 - 1 = 53
	jr .testBit
.notStrength
	; Must be FLASH
	ld c, 54 ; FLASH_TMNUM - 1 = 55 - 1 = 54
.testBit
	; c = bit index (0-54)
	; Calculate byte offset: c / 8
	ld a, c
	srl a
	srl a
	srl a
	; a = byte offset
	ld hl, wMonHLearnset
	ld e, a
	ld d, 0
	add hl, de
	; hl now points to the correct byte
	; Calculate bit mask: 1 << (c % 8)
	ld a, c
	and 7
	ld b, a  ; b = bit position (0-7)
	ld a, 1  ; start with bit 0 set
	; Shift left b times
	inc b    ; increment so we can use djnz
.shiftLoop
	dec b
	jr z, .doneShift
	sla a
	jr .shiftLoop
.doneShift
	; a = bit mask
	and [hl]
	jr z, .cannotLearn
	jr .canLearn
.checkLevelUp
	; Check level-up learnset for non-HM moves
	ld a, [wCurPartySpecies]
	dec a
	push bc
	ld bc, 0
	ld hl, EvosMovesPointerTable
	add a
	rl b
	ld c, a
	add hl, bc
	ld a, [hli]
	ld h, [hl]
	ld l, a
	pop bc
.skipEvos
	ld a, [hli]
	and a
	jr nz, .skipEvos
.checkLearnsetLoop
	ld a, [hli]
	and a
	jr z, .cannotLearn
	; a = level, next byte is move
	push bc
	ld c, [hl]
	inc hl
	ld a, b ; original move ID
	cp c
	pop bc
	jr nz, .checkLearnsetLoop
.canLearn
	pop hl
	pop de
	pop bc
	and a ; clear carry
	ret
.cannotLearn
	pop hl
	pop de
	pop bc
	scf ; set carry
	ret

; Check if Pokemon in [wWhichPokemon] knows move in register b
; Returns: carry clear if knows, carry set if doesn't know
DoesMonKnowMove:
	push de
	push hl
	ld a, [wWhichPokemon]
	ld hl, wPartyMon1Moves
	ld de, PARTYMON_STRUCT_LENGTH
	and a
	jr z, .skipMultiply
.multiply
	add hl, de
	dec a
	jr nz, .multiply
.skipMultiply
	ld d, h
	ld e, l
	ld c, NUM_MOVES
.loop
	ld a, [de]
	cp b
	jr z, .knows
	inc de
	dec c
	jr nz, .loop
	pop hl
	pop de
	scf ; doesn't know
	ret
.knows
	pop hl
	pop de
	and a ; knows it
	ret

GetMonFieldMoves:
	; First, check moves the Pokemon currently knows (original behavior)
	ld a, [wWhichPokemon]
	ld hl, wPartyMon1Moves
	ld bc, PARTYMON_STRUCT_LENGTH
	call AddNTimes
	ld d, h
	ld e, l
	ld c, NUM_MOVES
	ld hl, wFieldMoves
.loop
	ld a, [de] ; move ID
	and a
	jr z, .checkCanLearnMoves ; no more moves
	ld b, a
	inc de
	push bc
	push de
	push hl
	ld hl, FieldMoveDisplayData
.fieldMoveLoop
	ld a, [hli]
	cp $ff
	jr z, .nextMove ; if the move is not a field move
	cp b
	jr z, .foundFieldMove
	inc hl
	inc hl
	jr .fieldMoveLoop
.foundFieldMove
	ld a, b
	ld [wLastFieldMoveID], a
	ld a, [hli] ; field move name index
	ld b, [hl] ; field move leftmost X coordinate
	pop hl
	ld [hli], a ; store name index in wFieldMoves
	ld a, [wNumFieldMoves]
	inc a
	ld [wNumFieldMoves], a
	ld a, [wFieldMovesLeftmostXCoord]
	cp b
	jr c, .skipUpdatingLeftmostXCoord
	ld a, b
	ld [wFieldMovesLeftmostXCoord], a
.skipUpdatingLeftmostXCoord
	pop de
	pop bc
	dec c
	jr nz, .loop
	jr .checkCanLearnMoves
.nextMove
	pop hl
	pop de
	pop bc
	dec c
	jr nz, .loop
.checkCanLearnMoves
	; Now check Gen 1 HM field moves that can be learned
	; hl points to next free slot in wFieldMoves
	; Check CUT
	ld b, CUT
	call .checkHMFieldMove
	; Check FLY
	ld b, FLY
	call .checkHMFieldMove
	; Check SURF
	ld b, SURF
	call .checkHMFieldMove
	; Check STRENGTH
	ld b, STRENGTH
	call .checkHMFieldMove
	; Check FLASH
	ld b, FLASH
	call .checkHMFieldMove
	ret

.checkHMFieldMove
	; Input: b = move ID to check, hl = pointer to next free slot in wFieldMoves
	; Output: hl updated to point past any added entry
	push bc
	push de
	; First check if already in list
	ld a, [wNumFieldMoves]
	and a
	jr z, .notInList
	ld c, a ; count
	push bc
	push hl
	; Find what the name index would be for this move
	ld a, b
	ld e, a
	ld hl, FieldMoveDisplayData
.findNameIndex
	ld a, [hli]
	cp e
	jr z, .foundNameIndex
	inc hl
	inc hl
	jr .findNameIndex
.foundNameIndex
	ld a, [hl] ; name index
	ld d, a
	; Now check if this name index is already in wFieldMoves
	pop hl
	pop bc
	push hl
	ld hl, wFieldMoves
.checkDuplicateLoop
	ld a, [hli]
	cp d
	jr z, .alreadyInList
	dec c
	jr nz, .checkDuplicateLoop
	pop hl
	jr .notInList
.alreadyInList
	pop hl
	pop de
	pop bc
	ret
.notInList
	; Check if Pokemon can learn this move
	push hl
	push bc
	call CanLearnFieldMove
	pop bc
	pop hl
	jr c, .skipMove ; cannot learn
	; Check if we've already hit the limit
	push hl
	ld a, [wNumFieldMoves]
	cp NUM_MOVES
	pop hl
	jr nc, .skipMove ; already at max
	; Add this move
	push hl
	push bc
	ld a, b ; move ID
	ld c, a
	ld hl, FieldMoveDisplayData
.findMoveData
	ld a, [hli]
	cp c
	jr z, .foundMoveData
	inc hl
	inc hl
	jr .findMoveData
.foundMoveData
	ld a, [hli] ; name index
	ld d, a
	ld a, [hl] ; leftmost X coord
	ld e, a
	pop bc
	pop hl
	; Write to wFieldMoves
	ld a, d
	ld [hli], a
	; Update count
	ld a, [wNumFieldMoves]
	inc a
	ld [wNumFieldMoves], a
	; Update leftmost X
	ld a, [wFieldMovesLeftmostXCoord]
	cp e
	jr c, .doneAdding
	ld a, e
	ld [wFieldMovesLeftmostXCoord], a
.doneAdding
	pop de
	pop bc
	ret
.skipMove
	pop de
	pop bc
	ret

INCLUDE "data/moves/field_moves.asm"
