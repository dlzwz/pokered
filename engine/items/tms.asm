; tests if mon [wCurPartySpecies] can learn move [wMoveNum]
CanLearnTM:
	ld a, [wCurPartySpecies]
	ld [wCurSpecies], a
	call GetMonHeader
	ld hl, wMonHLearnset
	push hl
	ld a, [wMoveNum]
	ld b, a
	ld c, $0
	ld hl, TechnicalMachines
.findTMloop
	ld a, [hli]
	cp b
	jr z, .TMfoundLoop
	inc c
	jr .findTMloop
.TMfoundLoop
	pop hl
	ld b, FLAG_TEST
	predef_jump FlagActionPredef

; checks if [wCurPartySpecies] can learn move in a via TM/HM list
; returns a=0 if move is TM/HM and learnable, a=1 otherwise
CheckMonCanLearnTMHM:
	ld b, a
	ld hl, TechnicalMachines
	ld c, NUM_TM_HM
.findTMHM
	ld a, [hli]
	cp b
	jr z, .checkLearnset
	dec c
	jr nz, .findTMHM
	ld a, 1
	ret
.checkLearnset
	ld a, b
	ld [wMoveNum], a
	call CanLearnTM
	ld a, c
	and a
	jr z, .notAble
	xor a
	ret
.notAble
	ld a, 1
	ret

; converts TM/HM number in [wTempTMHM] into move number
; HMs start at 51
TMToMove:
	ld a, [wTempTMHM]
	dec a
	ld hl, TechnicalMachines
	ld b, $0
	ld c, a
	add hl, bc
	ld a, [hl]
	ld [wTempTMHM], a
	ret

INCLUDE "data/moves/tmhm_moves.asm"
