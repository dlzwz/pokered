This tutorial will allow use of HMs and other Field Moves / Overworld Moves (Rock Smash, Headbutt, Sweet Scent, Dig, Teleport) without Pokemon in the party needing to have learned the move, as long as they are capable of learning the move. 

By default, I also have code that checks for Badges required, and the presence of the HM/TM of the corresponding move in the bag. These checks are **optional**, so if you want an open world you can have it. 

For the TM Field moves, the assumption is that you've already implemented [Infinitely reusable TMs](Infinitely-reusable-TMs) so that once you acquire the TMs, they are permanent in the bag. If you do not wish to have [Infinitely reusable TMs](Infinitely-reusable-TMs) or to tie the use of the TM Field moves to needing to have a copy of the TM in the bag, you can link them to badges if you'd like, or have no other requirements except having a Pokemon capable of learning the move.

A major feature of this tutorial is adding location checks when populating the Pokemon Submenu, so that the Submenu does not get cluttered with Field Moves in situations where you can't even use them anyways.

This code should be compatible with most other features. Edits are needed to work with Pokecrystal16 or Polished Crystal. You can also easily adapt this tutorial to be compatible with any [new Field Moves](Add-a-new-field-move-effect) you may add or remove. Similarly, if you change the TMs or Move Tutor Moves of the game, very simple edits are all that should be required.

## 1. Adding the New CanPartyLearnMove Function we'll be using

Edit [engine/events/overworld.asm](../blob/master/engine/events/overworld.asm):

Starting off, this function mirrors a lot of other functions in the codebase that cycle through each Pokemon in the party. 
NOTE: It's important to remember that the Move in question must be loaded into register ```d``` before calling this function!!!!
We get the species and skip the mon if the species is 0 (empty party slot/end of party) or if it's an egg. Once we have the species in ```wCurPartySpecies``` via ```ld [wCurPartySpecies], a```  we ```farcall CanLearnTMHMMove``` which is the function that's used when you try to teach a Pokemon a TM or HM, so it's perfect for our uses here. The result is given in register ```c``` which we check. 

If the mon we're currently checking can learn the Move in ```d```, we return with the index of the party mon in ```wCurPartyMon```, zero out register ```a``` and don't bother checking the rest of the party.

If the TM/HM/Move tutor check fails, we then check the Mon's Level-up Moveset. This code is actually adapted from ax6 and Vulcandth's Pokecrystal16, and we also use the same code in the Mon Submenu!

All we do is check to see if the pokemon is capable of evolving, and if so, skip over the evolution data so we start at the Level up moves. If we find the move, we exit early. If we read a 0 for the Lvl-learned part of the entry, we know we've reached the end of the learnset, and exit because we obviously didn't find the move we're looking for. If we fail to find a mon in the party that can learn the Move, the Carry Flag is set via ```scf``` before we return.

```diff
CheckPartyMove:
; Check if a monster in your party has move d.
...
.no
	scf
	ret

+CheckPartyCanLearnMove:
+; CHECK IF MONSTER IN PARTY CAN LEARN MOVE D
+	ld e, 0
+	xor a
+	ld [wCurPartyMon], a
+.loop
+	ld c, e
+	ld b, 0
+	ld hl, wPartySpecies
+	add hl, bc
+	ld a, [hl]
+	and a
+	jr z, .no
+	cp -1
+	jr z, .no
+	cp EGG
+	jr z, .next
+
+	ld [wCurPartySpecies], a
+	ld a, d
+; Check the TM/HM/Move Tutor list
+	ld [wPutativeTMHMMove], a
+	push de
+	farcall CanLearnTMHMMove
+	pop de
+.check
+	ld a, c
+	and a
+	jr nz, .yes
+; Check the Pokemon's Level-Up Learnset
+	ld b,b
+	ld a, d
+	push de
+	call OW_CheckLvlUpMoves
+	pop de
+	jr nc, .yes
+; done checking
+
+.next
+	inc e
+	jr .loop
+
+.yes
+	ld a, e
+	; which mon can learn the move
+	ld [wCurPartyMon], a
+	xor a
+	ret
+.no
+	ld a, 1
+	ret
+
+OW_CheckLvlUpMoves:
+; move looking for in a
+	ld d, a
+	ld a, [wCurPartySpecies]
+	dec a
+	ld b, 0
+	ld c, a
+	ld hl, EvosAttacksPointers
+	add hl, bc
+	add hl, bc
+	ld a, BANK(EvosAttacksPointers)
+	ld b, a
+	call GetFarWord
+	ld a, b
+	call GetFarByte
+	inc hl
+	and a
+	jr z, .find_move ; no evolutions
+	dec hl ; does have evolution(s)
+	call OW_SkipEvolutions
+.find_move
+	call OW_GetNextEvoAttackByte
+	and a
+	jr z, .notfound ; end of mon's lvl up learnset
+	call OW_GetNextEvoAttackByte
+	cp d
+	jr z, .found
+	jr .find_move
+.found
+	xor a
+	ret ; move is in lvl up learnset
+.notfound
+	scf ; move isnt in lvl up learnset
+	ret
+
+OW_SkipEvolutions:
+; Receives a pointer to the evos and attacks, and skips to the attacks.
+	ld a, b
+	call GetFarByte
+	inc hl
+	and a
+	ret z
+	cp EVOLVE_STAT
+	jr nz, .no_extra_skip
+	inc hl
+.no_extra_skip
+	inc hl
+	inc hl
+	jr OW_SkipEvolutions
+
+OW_GetNextEvoAttackByte:
+	ld a, BANK(EvosAttacksPointers)
+	call GetFarByte
+	inc hl
+	ret
+
FieldMoveFailed:
```

## 2. TryCutOW

Edit [engine/events/overworld.asm](../blob/master/engine/events/overworld.asm):

Most of the functions we're editing in ```/engine/events/overworld.asm``` will mirror each other. 
Not much is needed to implement our new ```CheckPartyCanLearnMove``` function. 

First, we need to move the ```CheckPartyMove``` function to the end of the sequence, since it simply checks in any mons in the Party have the Move loaded into ```d``` as one of their 4 learned moves. Instead of checking this first thing, we move it to after ```CheckPartyCanLearnMove```. So now the function flows like this whenever the player interacts with a Cut Tree:

Step 1) Check if we have Hivebadge. If not, don't bother checking anything else, just exit with failure.
Step 2) Check if we have the CUT HM in the bag. If not, don't bother checking anything else, just exit with failure.
Step 3) Check if a Pokemon in the Party can learn CUT. If yes, we are done and jump to ```.yes``` and the Cut Tree will be cut. If not, we fallthrough to Step 4.
Step 4) Check if a Pokemon in the Party knows CUT. If not, we fail, and the Cut Tree cannot be Cut. If yes, we fallthrough to ```.yes``` and the Cut Tree will be cut.

In each step, pay attention to the logic checks done at the end of the step. If you ever want to customize the order or type of checks you want for the Field Moves or all the Field Moves, take the time to review the logic flow and make sure it's what you want.

```diff
TryCutOW::
-	ld d, CUT
-	call CheckPartyMove
-	jr c, .cant_cut
-
+; Step 1
	ld de, ENGINE_HIVEBADGE
	call CheckEngineFlag
	jr c, .cant_cut
+
+; Step 2
+	ld a, HM_CUT
+	ld [wCurItem], a
+	ld hl, wNumItems
+	call CheckItem
+	jr z, .cant_cut
+
+; Step 3
+	ld d, CUT
+	call CheckPartyCanLearnMove
+       and a
+	jr z, .yes
+
+; Step 4
+	ld d, CUT
+	call CheckPartyMove
+	jr c, .cant_cut
+.yes
	ld a, BANK(AskCutScript)
	ld hl, AskCutScript
	call CallScript
	scf
	ret

.cant_cut
	ld a, BANK(CantCutScript)
	ld hl, CantCutScript
	call CallScript
	scf
	ret
```

Technically, you COULD assume that no Pokemon could have an Overworld move in their moveset without being able to learn it, so Step 4 could be safely deleted if you're sure that it could never happen. I am leaving it in the interest of compatibility and testing reasons. There's also the case of special/event Pokemon like Surfing/Flying Pikachu. Since Pikachu can't normally learn Surf or Fly, if you remove the ```CheckPartyMove``` step then Pikachu won't be able to use Surf/Fly in the Overworld, for example. But if you are confident you don't need this check, you could modify this and the rest of the functions to look like: 

```diff
TryCutOW::
...
; Step 3
	ld d, CUT
	call CheckPartyCanLearnMove
        and a
-	jr z, .yes
-
-; Step 4
-	ld d, CUT
-	call CheckPartyMove
	jr c, .cant_cut
-.yes
	ld a, BANK(AskCutScript)
	ld hl, AskCutScript
	call CallScript
	scf
	ret
```

We don't need the ```.yes``` label anymore so we also get rid of it.

Similarly, if you don't want to make the use of HM Overworld moves dependant on having a Badge or having the HM/TM in the bag, just delete those steps entirely. 

## 3. TrySurfOW

Edit [engine/events/overworld.asm](../blob/master/engine/events/overworld.asm):

Nothing too different from ```TryCutOW```, Surf just has additional checks at the beginning that we don't need to mess with. After those, we still apply the same 4-Step checks.


```diff
TrySurfOW::
; Checking a tile in the overworld.
; Return carry if fail is allowed.

; Don't ask to surf if already fail.
	ld a, [wPlayerState]
	cp PLAYER_SURF_PIKA
	jr z, .quit
	cp PLAYER_SURF
	jr z, .quit

; Must be facing water.
	ld a, [wFacingTileID]
	call GetTileCollision
	cp WATER_TILE
	jr nz, .quit

; Check tile permissions.
	call CheckDirection
	jr c, .quit

+; Step 1
	ld de, ENGINE_FOGBADGE
	call CheckEngineFlag
	jr c, .quit

+; Step 2
+	ld a, HM_SURF
+	ld [wCurItem], a
+	ld hl, wNumItems
+	call CheckItem
+	jr z, .quit
+
+; Step 3
+  	ld d, SURF
+	call CheckPartyCanLearnMove
+	and a
+	jr z, .yes
+
+; Step 4
	ld d, SURF
	call CheckPartyMove
	jr c, .quit
+.yes
	ld hl, wBikeFlags
	bit BIKEFLAGS_ALWAYS_ON_BIKE_F, [hl]
	jr nz, .quit
```
## 4. TryWaterfallOW

Edit [engine/events/overworld.asm](../blob/master/engine/events/overworld.asm):

Nothing special to note here. Same 4-Steps, moving the ```CheckPartyMove``` code to be the last check instead of the first.

```diff
TryWaterfallOW::
-	ld d, WATERFALL
-	call CheckPartyMove
-	jr c, .failed
+; Step 1
	ld de, ENGINE_RISINGBADGE
	call CheckEngineFlag
	jr c, .failed
+
+; Step 2
+	ld a, HM_WATERFALL
+	ld [wCurItem], a
+	ld hl, wNumItems
+	call CheckItem
+	jr z, .failed
+
+; Step 3
+	ld d, WATERFALL
+	call CheckPartyCanLearnMove
+	and a
+	jr z, .yes
+
+; Step 4
+	ld d, WATERFALL
+	call CheckPartyMove
+	jr c, .failed
+.yes
	call CheckMapCanWaterfall
	jr c, .failed
```

## 5. TryStrengthOW

Edit [engine/events/overworld.asm](../blob/master/engine/events/overworld.asm):

Same thing for Strength, we move ```CheckPartyMove``` code to be Step 4 instead of the first thing checked.

```diff
TryStrengthOW:
-	ld d, STRENGTH
-	call CheckPartyMove
-	jr c, .nope
+; Step 1	
	ld de, ENGINE_PLAINBADGE
	call CheckEngineFlag
	jr c, .nope

+; Step 2
+	ld a, HM_STRENGTH
+	ld [wCurItem], a
+	ld hl, wNumItems
+	call CheckItem
+	jr z, .nope
+
+; Step 3
+	ld d, STRENGTH
+	call CheckPartyCanLearnMove
+	and a
+	jr z, .yes
+
+; Step 4
+	ld d, STRENGTH
+	call CheckPartyMove
+	jr c, .nope
+
+.yes
	ld hl, wBikeFlags
	bit BIKEFLAGS_STRENGTH_ACTIVE_F, [hl]
	jr z, .already_using
```

## 6. TryWhirlpoolOW

Edit [engine/events/overworld.asm](../blob/master/engine/events/overworld.asm):

Whirlpool has more complicated functions surrounding ```TryWhirlpoolOW``` but according to my testing, they don't actually do much if anything. However, there is a problem SOMEWHERE, considering there's a small graphical bug with my code here. If you examine a Whirlpool without having the badge or the TM (either or both) the text box goes yellow then blue the next time you examine it. As far as I can tell, it doesn't do anything else besides this color thing. But if anyone finds the source of this bug, a solution or work around, please let me know or directly edit this tutorial if you're sure!

```diff
TryWhirlpoolOW::
-	ld d, WHIRLPOOL
-	call CheckPartyMove
-	jr c, .failed
+; Step 1
	ld de, ENGINE_GLACIERBADGE
-	call CheckEngineFlag
-	jr c, .failed
+	ld b, CHECK_FLAG
+	farcall EngineFlagAction
+	ld a, c
+	and a
+	jr z, .failed  ; .fail, dont have needed badge
+
+; Step 2
+	ld a, HM_WHIRLPOOL
+	ld [wCurItem], a
+	ld hl, wNumItems
+	call CheckItem
+	jr z, .failed
+
+; Step 3
+	ld d, WHIRLPOOL
+	call CheckPartyCanLearnMove
+       and a
+	jr z, .yes
+
+; Step 4
+	ld d, WHIRLPOOL
+	call CheckPartyMove
+	jr c, .failed
+
+.yes
	call TryWhirlpoolMenu
	jr c, .failed

	ld a, BANK(Script_AskWhirlpoolOW)
	ld hl, Script_AskWhirlpoolOW
	call CallScript
	scf
	ret

.failed
	ld a, BANK(Script_MightyWhirlpool)
	ld hl, Script_MightyWhirlpool
	call CallScript
	scf
	ret
```

## 7. TryHeadbuttOW

Edit [engine/events/overworld.asm](../blob/master/engine/events/overworld.asm):

Now we're done with the HMs and onto the TM Field moves! Nothing too different, except no more badge checks (unless you want to add a badge check, feel free!) 

```diff
TryHeadbuttOW::
+; Step 1
+	ld a, TM_HEADBUTT
+	ld [wCurItem], a
+	ld hl, wNumItems
+	call CheckItem
+	jr z, .no
+
+; Step 2
+	ld d, HEADBUTT
+	call CheckPartyCanLearnMove
+       and a
+	jr z, .can_use ; cannot learn headbutt
+
+; Step 3
	ld d, HEADBUTT
	call CheckPartyMove
	jr c, .no
+.can_use
	ld a, BANK(AskHeadbuttScript)
	ld hl, AskHeadbuttScript
	call CallScript
	scf
	ret

.no
	xor a
	ret
```

## 8. HasRockSmash

Edit [engine/events/overworld.asm](../blob/master/engine/events/overworld.asm):

Pretty Self explanatory at this point, you're an expert!

```diff
HasRockSmash:
-	ld d, ROCK_SMASH
-	call CheckPartyMove
-	jr nc, .yes
-; no
+; Step 1
+	ld a, TM_ROCK_SMASH
+	ld [wCurItem], a
+	ld hl, wNumItems
+	call CheckItem
+	jr z, .no
+
+; Step 2
+	ld d, ROCK_SMASH
+	call CheckPartyCanLearnMove
+       and a
+	jr z, .yes
+
+; Step 3
+	ld d, ROCK_SMASH
+	call CheckPartyMove
+	jr nc, .yes
+.no
	ld a, 1
	jr .done
.yes
	xor a
	jr .done
.done
	ld [wScriptVar], a
	ret
```

## 9. Editing the Pokemon Submenu

Edit [engine/pokemon/mon_submenu.asm](../blob/master/engine/pokemon/mon_submenu.asm):

The main differences between the submenu and the interaction moves are that the submenu doesn't check the whole party at once. When we click the party Mon from our list in the party menu, the submenu is populated at that moment, for that single pokemon. We are only checking one mon at a time. Normally, this function, ```GetMonSubmenuItems``` checks the 4 moves of the pokemon. We remove that code and use it later as a seperate function used by these new functions we've called below.

The new functions determine if that OW move will be added to the submenu, in the order called. For example, if a pokemon can use Flash and Sweet Scent, Flash will be above Sweet Scent on the submenu in the example shown below. Feel free to re-arrange the order you call these functions, it makes no difference in how the overall system behaves. 

```diff
GetMonSubmenuItems:
	call ResetMonSubmenu
	ld a, [wCurPartySpecies]
	cp EGG
	jr z, .egg
	ld a, [wLinkMode]
	and a
	jr nz, .skip_moves
-	ld a, MON_MOVES
-	call GetPartyParamLocation
-	ld d, h
-	ld e, l
-	ld c, NUM_MOVES
-.loop
-	push bc
-	push de
-	ld a, [de]
-	and a
-	jr z, .next
-	push hl
-	call IsFieldMove
-	pop hl
-	jr nc, .next
-	call AddMonMenuItem
-
-.next
-	pop de
-	inc de
-	pop bc
-	dec c
-	jr nz, .loop
+
+	call CanUseFlash
+	call CanUseFly
+	call CanUseDig
+	call Can_Use_Sweet_Scent
+	call CanUseTeleport
+	call CanUseSoftboiled
+	call CanUseMilkdrink

.skip_moves
	ld a, MONMENUITEM_STATS
	call AddMonMenuItem
	ld a, MONMENUITEM_SWITCH
	call AddMonMenuItem
	ld a, MONMENUITEM_MOVE
	call AddMonMenuItem
```

## 10. New Submenu Functions

Edit [engine/pokemon/mon_submenu.asm](../blob/master/engine/pokemon/mon_submenu.asm):

I put all these functions at the end of the file.

So our new functions are: ```CheckMonCanLearn_TM_HM``` (which also checks the Move tutor moves as they are included in the list), ```CheckMonKnowsMove``` and ```CheckLvlUpMoves```. The two helper functions, ```MonSubMenu_SkipEvolutions``` and ```MonSubMenu_GetNextEvoAttackByte``` are used by ```CheckLvlUpMoves``` exactly the same as we've previously implemented in ```engine/events/overworld.asm```.

The code for ```CheckMonKnowsMove``` is pretty much exactly what we removed from ```GetMonSubmenuItems``` earlier.


```diff
+CheckMonCanLearn_TM_HM:
+; Check if wCurPartySpecies can learn move in 'a'
+	ld [wPutativeTMHMMove], a
+	ld a, [wCurPartySpecies]
+	farcall CanLearnTMHMMove
+.check
+	ld a, c
+	and a
+	ret z
+; yes
+	scf
+	ret
+
+CheckMonKnowsMove:
+	ld b, a
+	ld a, MON_MOVES
+	call GetPartyParamLocation
+	ld d, h
+	ld e, l
+	ld c, NUM_MOVES
+.loop
+	ld a, [de]
+	and a
+	jr z, .next
+	cp b
+	jr z, .found ; knows move
+.next
+	inc de
+	dec c
+	jr nz, .loop
+	ld a, -1
+	scf ; mon doesnt know move
+	ret
+.found
+	xor a
+	ret z
+
+CheckLvlUpMoves:
+; move looking for in a
+	ld d, a
+	ld a, [wCurPartySpecies]
+	dec a
+	ld b, 0
+	ld c, a
+	ld hl, EvosAttacksPointers
+	add hl, bc
+	add hl, bc
+	ld a, BANK(EvosAttacksPointers)
+	ld b, a
+	call GetFarWord
+	ld a, b
+	call GetFarByte
+	inc hl
+	and a
+	jr z, .find_move
+	dec hl
+	call MonSubMenu_SkipEvolutions
+.find_move
+	call MonSubMenu_GetNextEvoAttackByte
+	and a
+	jr z, .notfound ; end of mon's lvl up learnset
+	call MonSubMenu_GetNextEvoAttackByte
+	cp d ;MAKE SURE NOT CLOBBERED
+	jr z, .found
+	jr .find_move
+.found
+	xor a
+	ret z ; move is in lvl up learnset
+.notfound
+	scf ; move isnt in lvl up learnset
+	ret
+
+MonSubMenu_SkipEvolutions:
+; Receives a pointer to the evos and attacks for a mon in b:hl, and skips to the attacks.
+	ld a, b
+	call GetFarByte
+	inc hl
+	and a
+	ret z
+	cp EVOLVE_STAT
+	jr nz, .no_extra_skip
+	inc hl
+.no_extra_skip
+	inc hl
+	inc hl
+	jr MonSubMenu_SkipEvolutions
+
+MonSubMenu_GetNextEvoAttackByte:
+	ld a, BANK(EvosAttacksPointers)
+	call GetFarByte
+	inc hl
+	ret
```

## 11. Flash

Edit [engine/pokemon/mon_submenu.asm](../blob/master/engine/pokemon/mon_submenu.asm):

Again, I put ALL the following functions at the end of the file for convinience.

Similarly to the interactable moves that we edited in ```engine/events/overworld.asm```, we use a multi-step system, but with a few changes. Namely, we check if the Pokemon knows the Move and allow it to be added to the submenu if it does know the Move, without checking if the TM/HM is in the bag.

I'll go into more detail later (the change was made because of Sweet Scent), ultimately it doesn't matter as all the checks will work in almost any order as long as you properly edit the return conditions to follow the logic you want.

But the change was made because some pokemon like Oddish learn Sweet Scent at a very early level, and you can aquire Oddish before you get the TM for Sweet Scent. And I figured, as long as the pokemon knows the move why should you need the TM? You can also use this logic for the functions in ```engine/events/overworld.asm``` if you like. Basically, instead of failing when a mon doesn't know the move, you simply change the logic to jump to success if it does know it.

The second big changes you'll see are Location Appropiateness checks. For Flash, we don't want it to be shown on the Submenu unless we're in a Dark Cave or in the special Aerodactyl chamber puzzle room. Once you do use Flash in a dark cave, it's no longer dark, so it won't appear in the submenu after that unless you exit and re-enter the cave.

A small change is that we now check TM/HM/Move tutor moves in a seperate function from the Lvl Up learn sets. Not a big deal, it was just easier to combine the check in ```engine/events/overworld.asm```.

Individual Steps:

Step 1: Badge Check
Step 2: Location Check
Step 3: Check if Mon knows Move. If yes, skip to adding move to submenu. if no, go to step 4
Step 4: Check for TM/HM in bag
Step 5: Check if Mon can learn move from TM/HM/Move Tutor. If yes, add to submenu. if no, check LVL-UP
Step 6: Check if Mon can learn move from LVL-UP. If this step fails, return without adding move to submenu


```diff
+CanUseFlash:
+; Step 1: Badge Check
+	ld de, ENGINE_ZEPHYRBADGE
+	ld b, CHECK_FLAG
+	farcall EngineFlagAction
+	ld a, c
+	and a
+	ret z ; .fail, dont have needed badge
+
+; Step 2: Location Check
+	farcall SpecialAerodactylChamber
+	jr c, .valid_location ; can use flash
+	ld a, [wTimeOfDayPalset]
+	cp DARKNESS_PALSET
+	ret nz ; .fail ; not a darkcave
+
+.valid_location
+; Step 3: Check if Mon knows Move
+	ld a, FLASH
+	call CheckMonKnowsMove
+	and a
+	jr z, .yes
+
+; Step 4: Check for TM/HM in bag
+	ld a, HM_FLASH
+	ld [wCurItem], a
+	ld hl, wNumItems
+	call CheckItem
+	ret nc ; hm isnt in bag
+
+; Step 5: Check if Mon can learn move from TM/HM/Move Tutor
+	ld a, FLASH
+	call CheckMonCanLearn_TM_HM
+	jr c, .yes
+
+; Step 6: Check if Mon can learn move from LVL-UP
+	ld a, FLASH
+	call CheckLvlUpMoves
+	ret c ; fail
+
+.yes
+	ld a, MONMENUITEM_FLASH
+	call AddMonMenuItem
+	ret
```

## 12. Fly

Edit [engine/pokemon/mon_submenu.asm](../blob/master/engine/pokemon/mon_submenu.asm):

Almost identical to Flash, except the Location check is simply if the Player is outdoors or not.

```diff
+CanUseFly:
+; Step 1: Badge Check
+	ld de, ENGINE_STORMBADGE
+	ld b, CHECK_FLAG
+	farcall EngineFlagAction
+	ld a, c
+	and a
+	ret z ; .fail, dont have needed badge
+
+; Step 2: Location Check
+	call GetMapEnvironment
+	call CheckOutdoorMap
+	ret nz ; not outdoors, cant fly
+
+; Step 3: Check if Mon knows Move
+	ld a, FLY
+	call CheckMonKnowsMove
+	and a
+	jr z, .yes
+
+; Step 4: Check if HM is in bag
+	ld a, HM_FLY
+	ld [wCurItem], a
+	ld hl, wNumItems
+	call CheckItem
+	ret nc ; .fail, hm isnt in bag
+
+; Step 5: Check if mon can learn move via HM/TM/Move Tutor
+	ld a, FLY
+	call CheckMonCanLearn_TM_HM
+	jr c, .yes
+
+; Step 6: Check if Mon can learn move via LVL-UP
+	ld a, FLY
+	call CheckLvlUpMoves
+	ret c ; fail
+.yes
+	ld a, MONMENUITEM_FLY
+	call AddMonMenuItem
+	ret
```

## 13. Sweet Scent

Edit [engine/pokemon/mon_submenu.asm](../blob/master/engine/pokemon/mon_submenu.asm):

No badge check needed, first we check if the location is appropiate. Thankfully we can use already existing functions that determine if Sweet Scent will work or not, and use them here to check the location. Sweet scent will only work in caves if we're not sliding on ice, or in a patch of grass, or in a dungeon with an encounter rate like Ilex Forest.

```diff
+Can_Use_Sweet_Scent:
+; Step 1: Location check
+	farcall CanEncounterWildMon ; CanUseSweetScent instead for older versions of pokecrystal
+	ret nc
+	farcall GetMapEncounterRate
+	ld a, b
+	and a
+	ret z
+
+.valid_location
+; Step 2: Check if mon knows Move 
+	ld a, SWEET_SCENT
+	call CheckMonKnowsMove
+	and a
+	jr z, .yes
+
+; Step 3: Check if TM is in bag
+	ld a, TM_SWEET_SCENT
+	ld [wCurItem], a
+	ld hl, wNumItems
+	call CheckItem
+	ret nc ; .fail, tm not in bag
+
+; Step 4: Check if mon can learn Move via TM/HM/Move tutor
+	ld a, SWEET_SCENT
+	call CheckMonCanLearn_TM_HM
+	jr c, .yes
+
+; Step 5: Check if mon can learn move via LVL-UP
+	ld a, SWEET_SCENT
+	call CheckLvlUpMoves
+	ret c ; fail
+.yes
+	ld a, MONMENUITEM_SWEETSCENT
+	call AddMonMenuItem
+	ret
```

## 14. Dig

Edit [engine/pokemon/mon_submenu.asm](../blob/master/engine/pokemon/mon_submenu.asm):
Pretty simple, Dig is a TM so we do check for it in Step 3. First check is the location check, Dig will fail if not in a cave or a dungeon like the Rocket Hideout.

```diff
+CanUseDig:
+; Step 1: Location Check
+	call GetMapEnvironment
+	cp CAVE
+	jr z, .valid_location
+	cp DUNGEON
+	ret nz ; fail, not inside cave or dungeon
+
+.valid_location
+; Step 2: Check if Mon knows Move
+	ld a, DIG
+	call CheckMonKnowsMove
+	and a
+	jr z, .yes
+
+; Step 3: Check if TM/HM is in bag
+	ld a, TM_DIG
+	ld [wCurItem], a
+	ld hl, wNumItems
+	call CheckItem
+	ret nc ; .fail ; TM not in bag
+
+; Step 4: Check if Mon can learn Dig via TM/HM/Move Tutor
+	ld a, DIG
+	call CheckMonCanLearn_TM_HM
+	jr c, .yes
+
+; Step 5: Check if Mon can learn move via LVL-UP
+	ld a, DIG
+	call CheckLvlUpMoves
+	ret c ; fail
+.yes
+	ld a, MONMENUITEM_DIG
+	call AddMonMenuItem
+	ret
```

## 15. Teleport

Edit [engine/pokemon/mon_submenu.asm](../blob/master/engine/pokemon/mon_submenu.asm):

Pretty simple. The location check for Teleport is that we're outdoors. Teleport will fail if you try to use it indoors or in a cave. There's no TM or Move Tutor for Teleport so we don't have the ```CheckMonCanLearn_TM_HM``` step. Feel free to add it if you make Teleport into a TM, or add a badge check if you feel it's appropiate.

```diff
+CanUseTeleport:
+; Step 1: Location Check
+	call GetMapEnvironment
+	call CheckOutdoorMap
+	ret nz ; .fail
+	
+; Step 2: Check if mon knows move
+	ld a, TELEPORT
+	call CheckMonKnowsMove
+	and a
+	jr z, .yes
+
++; Step 3: Check if mon learns move via LVL-UP
+	ld a, TELEPORT
+	call CheckLvlUpMoves
+	ret c ; fail
+.yes
+	ld a, MONMENUITEM_TELEPORT
+	call AddMonMenuItem	
+	ret
```

## 16. Softboiled and Milk Drink

Edit [engine/pokemon/mon_submenu.asm](../blob/master/engine/pokemon/mon_submenu.asm):

These two are special. We only check if the pokemon knows the move, they don't require badges (unless you want them to) and they don't have TMs or Move Tutor moves. But even if they did, the Pokemon would still need to actually know the move. In order to use these moves on the submenu, PP is consumed. So the Mon needs to actually know the move or else they will fail and not do anything. So we will only show them on the submenu if the Pokemon knows the move.

```diff
+CanUseSoftboiled:
+	ld a, SOFTBOILED
+	call CheckMonKnowsMove
+	and a
+	ret nz
+	ld a, MONMENUITEM_SOFTBOILED
+	call AddMonMenuItem
+	ret
```


```diff
+CanUseMilkdrink:
+	ld a, MILK_DRINK
+	call CheckMonKnowsMove
+	and a
+	ret nz
+
+	ld a, MONMENUITEM_MILKDRINK
+	call AddMonMenuItem
+	ret
```

That's it for most people. IF you want to adapt this for Polished Crystal or Pokecrystal16, keep reading. If not, good luck! This is a long but hopefully straightforward tutorial that should make you comfortable editing to suit your preferences and needs for your rom hack.

If you have any questions, you can find help in the Pret discord server. If you have problems, please be VERY SPECIFIC with what code base you're using, what your goal is, and what changes you've made so far! It will be much easier to help you that way.

![bayleef_moves](https://user-images.githubusercontent.com/110363717/189774774-7e647b09-120f-4c19-8246-76544354d3e7.png)
![bayleef_flash_sweetscet](https://user-images.githubusercontent.com/110363717/189774834-888eabfc-7a0e-4de0-af56-1ffec610144d.png)

## 17. OPTIONAL TM Flag Array or Polished Crystal Compatibility

Changes for [Polished Crystal](https://github.com/Rangi42/polishedcrystal) by Rangi:

Polished Crystal changes Rock Smash to Brick Break, so any mention of Rock Smash in the code will need to have that minor edit.

Polished Crystal also removes Headbutt as a TM Move (it's a move tutor move instead, so the functions that test TM/HM/Move tutor moves will still work) so remove the bag check for Headbutt.

Polished Crystal also removes Sweet Scent from the game, so remove the call and function for it entirely.

Lastly, Polished Crystal uses a very nice Flag Array for the Infinite-use TM's. Other hacks may have this too, although the Infinite TM use tutorial doesn't say how to implement it. Just in case, here it is. 

Any References to checking TM/HMs in the bag will need to be changed to a slightly longer version. 

Here is an example with Fly:

```diff
-	ld a, HM_FLY
-	ld [wCurItem], a
-	ld hl, wNumItems
-	call CheckItem
-	ret nc ; .fail, hm isnt in bag
-	
+	ld a, HM_FLY
+	push bc
+	push de
+	ld e, a
+	ld d, 0
+	ld b, CHECK_FLAG
+	ld hl, wTMsHMs
+	call FlagAction
+	ld a, c
+	pop de
+	pop bc
+	and a
+	ret z ; ; .fail, hm isnt in bag
```

## 18. OPTIONAL New Pokecrystal16 Compatibility

First things first, in **BOTH** ```/engine/events/overworld.asm``` and ```/engine/pokemon/mon_submenu.asm``` we are consolidating the three functions that we used to check the Pokemons' Level-Up Learnsets: ```CheckLvlUpMoves```, ```SkipEvolutions```, and ```GetNextEvoAttackByte```. We can do this because I originally derived these three functions from the Functionality added into Pokecrystal16! So we are returning to that nice crisp native environment.

This is the new all-in-one function that BOTH files will be using, be sure to give them different names to avoid a build error!

```diff
+CheckLvlUpMoves:
+	ld d, a
+	ld a, [wTempSpecies]
+	call GetPokemonIndexFromID
+	ld b, h
+	ld c, l
+	ld hl, EvosAttacksPointers
+	ld a, BANK(EvosAttacksPointers)
+	call LoadDoubleIndirectPointer
+	ld [wStatsScreenFlags], a ; bank
+	call FarSkipEvolutions
+.learnset_loop
+	call GetFarByte
+  	and a
+	jr z, .notfound
+	inc hl
+	call GetFarWord
+	call GetMoveIDFromIndex
+	cp d
+	jr z, .found
+	inc hl
+	inc hl
+	jr .learnset_loop
+
+.found
+	xor a
+	ret ; move is in lvl up learnset
+.notfound
+	scf ; move isnt in lvl up learnset
+	ret
``` 

The only other changes needed are changing all places we load the Field Move into the ```a``` register before calling one of our functions. We need to instead load the Field Move into ```hl``` then translate the Move Index into the Move ID so our functions can use them. This is how the native Pokecrystal16 functions do it so we do it the same way, and it works perfectly. Here is an example with Dig:

```diff
CanUseDig:
	call GetMapEnvironment
	cp CAVE
	jr z, .valid_location
	cp DUNGEON
	ret nz ; fail, not inside cave or dungeon

.valid_location
-       ld a, DIG
+	ld hl, DIG
+	call GetMoveIDFromIndex
	call CheckMonKnowsMove
	and a
	jr z, .yes

	ld a, TM_DIG
	ld [wCurItem], a
	ld hl, wNumItems
	call CheckItem
	ret nc ; .fail ; TM not in bag

-       ld a, DIG
+	ld hl, DIG
+	call GetMoveIDFromIndex
	call CheckMonCanLearn_TM_HM
	jr c, .yes

-       ld a, DIG
+	ld hl, DIG
+	call GetMoveIDFromIndex
	call Submenu_CheckLvlUpMoves
	ret c ; fail
.yes
	ld a, MONMENUITEM_DIG
	call AddMonMenuItem
	ret
```

You will need to do this in ```/engine/events/overworld.asm``` for: ```TryCutOW::```, ```HasRockSmash:```, ```TryHeadbuttOW::```, ```TrySurfOW::```, ```TryWhirlpoolOW::```, and ```TryWaterfallOW::```.

In ```/engine/pokemon/mon_submenu.asm``` we need to edit these functions: ```CanUseFlash:```, ```CanUseFly:```, ```CanUseDig:```, ```Can_Use_Sweet_Scent:```, ```CanUseTeleport:```, ```CanUseSoftboiled:```, and ```CanUseMilkdrink:```.

That's it! Plus any custom Field Move functions you may add.       