// ===========================================================================
// Resource manager                                                          \
// By Jack Abraham                                                        \__ 
// ===========================================================================

integer useActDamage = TRUE;
integer sameGroupOnly = FALSE;      // Only play with my group
integer peacePrim;                  // Display for useActDamage
float DB_DENOMINATOR = 32.0;        // This much DB gives 2× protection
float DODGE_FOCUS_MULT = 2.0;       // Focus multiplier for successful defense

string attackers;                   // Colon-delimited list of keys for objects
                                    // that have already damaged you this turn

// Values stored in faces:
//  Face 0: Nutrition, Arousal, 
integer NEEDS = 0;
//  Face 1: Resiliance, Drive, Insight
integer RDI = 1;
//  Face 2: Damage status conditions, Morale, Focus
integer SMF = 2;
//  Face 3: Defense Bonus, Damage Resistance, Combat status conditions
integer DEFENSES = 3;
//  Face 4: Displayed face toward user; do not use for storage
integer DISPLAY_FACE = 4;
//  Face 5: Focus recovery rate, Max Focus, Morale recovery rate
integer RECOVERY = 5;
// Face 6: Damage modifier, DB modifier, conditions mask
integer COMBAT = 6;

// Bitmasks for states (resources.x)
integer STUNNED_MASK = 0x2;         // ?
integer RESTRAINED_MASK = 0x4;      // ?
integer DEFEATED_MASK = 0x8;        // ?
integer WOUNDED_MASK = 0x10;        // ?
integer VULNERABLE_MASK = 0x80;     //
integer TURN_MASK = 0x100;          // Using turn-based time
integer SEX_MASK = 0x200;           // Using Sex Act!

// Bitmasks for combat status (defenses.z)
integer COMBAT_MASK = 0x01;         //
integer INVULNERABLE_MASK = 0x02;   //
integer DEFENDING_MASK = 0x04;      //
integer PEACE_MASK = 0x08;          //

integer inCombat;                   // Used to reset combat time trackers

float stunnedUntil;
float restrainedUntil;
float woundedUntil;
float vulnerableUntil;
float lastDodge;
float invulnerableUntil;
float damageBuffUntil;

float STUNNED_TIME = 5.0;           // How long to be stunned by excess damage
float KO_TIME = 60.0;               // How long to be defeated

list shield;                        // Shield key, fraction passed through,
                                    // range, expiration time

integer statusMsg = FALSE;          // Send Morale & Focus status

integer menuPrim;
integer commPrim;
integer combatPrim;
integer teamPrim;
integer actMenuPrim;

key ACT_ICON = "70d6027a-f4e2-4cbe-70f3-85d218083b13";
key SEX_ACT_ICON = "d2dca9fb-85e9-7fe1-cee3-2153271ef85a";

handle_command( integer sender, integer signal, string msg, key id )
{
    if ( signal & RP_MASK ) {
        // llOwnerSay( llGetLinkName( sender ) + ":" + (string)signal + ": " + msg );

        string cmd = llGetSubString( msg, 0, 3 );
        if ( cmd == "act!" ) {
            if ( sameGroupOnly ) {
                if ( !llSameGroup( llGetOwnerKey(id) ) ) {
                    return;
                }
            }
            list parsed = llParseString2List( msg, 
                [ ACT_DELIM, LINK_DELIM ], [] );
            cmd = llList2String( parsed, 1 );
            // llOwnerSay( "Act! command: " + llList2CSV( parsed ) );
            
            // Take damage & reduce focus
            if ( cmd == "a!dmg" ) {
                take_damage( llList2List( parsed, 2, -1 ), 
                    id );
            } else if ( cmd == "a!fcs" ) {
                use_focus( llList2List( parsed, 2, -1 ) );
            // Adjust attributes, defenses, resources, etc.
            } else if ( cmd == "a!def" ) {
                vector buff = (vector)llList2String( parsed, 2 );
                vector def = retrieve( DEFENSES );
                store( <def.x + buff.x, def.y + buff.y, def.z>, DEFENSES );
            } else if ( cmd == "a!set" ) {
                vector setting = (vector)llList2String( parsed, 2 );
                float expires = setting.z + llGetTime();
                integer states;
                if ( setting.x ) {
                    states = (integer)setting.x;
                    if ( ( states & STUNNED_MASK ) && expires > 0.1 ) {
                        stunnedUntil = llListStatistics( LIST_STAT_MAX,
                            [ stunnedUntil, expires ] );
                    }
                    if ( ( states & RESTRAINED_MASK ) && expires > 0.1 ) {
                        restrainedUntil = llListStatistics( LIST_STAT_MAX,
                            [ restrainedUntil, expires ] );
                    }
                    if ( ( states & WOUNDED_MASK ) && expires > 0.1 ) {
                        woundedUntil = llListStatistics( LIST_STAT_MAX,
                            [ woundedUntil, expires ] );
                    }
                    if ( ( states & VULNERABLE_MASK ) && expires > 0.1 ) {
                        vulnerableUntil = llListStatistics( LIST_STAT_MAX,
                            [ vulnerableUntil, expires ] );
                    }
                    vector smf = retrieve( SMF );
                    if ( setting.z > 0.0 ) {
                        smf.x = (integer)smf.x | ( states ^ DEFEATED_MASK );
                    } else {
                        smf.x = (integer)smf.x & ~states;
                    }
                    store( smf, SMF );
                }
                if ( setting.y ) {
                    states = (integer)setting.y;
                    if ( ( states & INVULNERABLE_MASK ) && expires > 0.1 ) {
                        invulnerableUntil = llListStatistics( LIST_STAT_MAX,
                            [ invulnerableUntil, expires ] );
                    }
                    vector def = retrieve( DEFENSES );
                    if ( expires ) {
                        def.z = (integer)def.z | states;
                    } else {
                        def.z = (integer)def.z & ~states;
                    }
                    store( def, DEFENSES );
                }
            } else if ( cmd == "a!atr" ) {
                store( retrieve( RDI ) 
                    + (vector)llList2String( parsed, 2 ), RDI );
            } else if ( cmd == "a!rec" ) {
                vector rec = retrieve( RECOVERY );
                float time = (float)llList2String( parsed, 2 );
                use_focus( [ -1 * rec.x * time ] );
            } else if ( cmd == "a!atk" ) {
                //llOwnerSay( llGetScriptName() + " heard " +
                //    llList2CSV( parsed ) );
                if( llGetListLength( parsed ) < 4 ) return;
                vector buff = (vector)llList2String( parsed, 2 );
                float duration = (float)llList2String( parsed, 3 );
                
                vector def = retrieve( COMBAT );
                
                // Debuff
                if ( duration < 0.1 ) {
                    if ( buff.x ) {
                        def.x = 0.0;
                    }
                    if ( buff.y ) {
                        def.y = 0.0;
                    }
                    if ( buff.z ) {
                        def.z = (float)( (integer)def.z ^
                            (integer)buff.z );
                    }
                    store( def, COMBAT );
                    return;
                }
                    
                damageBuffUntil = llListStatistics( LIST_STAT_MAX,
                    [ damageBuffUntil, llGetTime() + duration ] );
                integer dmgMod = (integer)def.x;
                integer DBmod = (integer)def.z;
                
                if ( buff.x ) {
                    if ( dmgMod == 0 ) dmgMod = 5;
                    dmgMod += (integer)buff.x;
                    if ( dmgMod > 0xE ) dmgMod = 0xE;
                    else if ( dmgMod < 0 ) dmgMod = 0;
                }

                if ( buff.y ) {
                    DBmod = (integer)( def.y + 
                        ( buff.y / 8.0 ) + 5.0 );
                    if ( DBmod > 0xE ) DBmod = 0xE;
                    else if ( DBmod < 0 ) DBmod = 0;
                }
                
                integer flags = (integer)def.z | (integer)buff.z;
                
                store( <dmgMod, DBmod, flags>, COMBAT );
            } else if ( cmd == "a!rec" ) {
                store( retrieve( RECOVERY ) 
                   + (vector)llList2String( parsed, 2 ), RECOVERY );
            } else if ( cmd == "a!buf" ) {
                vector buff = (vector)llList2String( parsed, 2 );
                vector smf = retrieve( SMF );
                update_resources( <smf.x, smf.y + buff.y, smf.z + buff.z> );
                if ( statusMsg ) {
                    if ( buff.y ) {
                        if ( buff.y > 0 ) {
                            llOwnerSay( "Morale +" + (string)llRound(buff.y) );
                        } else {
                            llOwnerSay( "Morale " + (string)llRound(buff.y) );
                        }
                    } else  if ( buff.z ) {
                        if ( buff.z > 0 ) {
                            llOwnerSay( "Focus +" + (string)llRound(buff.z) );
                        } else {
                            llOwnerSay( "Focus " + (string)llRound(buff.z) );
                        }
                    }
                }
            } else if ( cmd == "turn" ) {
                // New turn in turn-based activity
                if ( get_flag( TURN_MASK ) ) {
                    resting_recovery();
                }
            } else if ( cmd == "focus" ) {
                integer level = signal & 0xFF;
                if ( level ) {
                    vector smf = retrieve( SMF );
                    vector rdi = retrieve( RDI );
                    smf.z = smf.z + ( rdi.z * (float)level / 20.0 );
                    store( smf, SMF );
                    llWhisper( power_channel( llGetOwner() ),
                        llDumpList2String( [ llGetOwner(), "play",
                            "focus end", 0.0 ], CHAT_DELIM ) );
                } else {
                    llWhisper( power_channel( llGetOwner() ),
                        llDumpList2String( [ llGetOwner(), "play",
                            "focus", 0.0 ], CHAT_DELIM ) );
                }
            } else if ( cmd == "peace" ) {
                useActDamage = !useActDamage;
                set_prim_lit( peacePrim, !useActDamage );
                vector defenses = retrieve( DEFENSES );
                if ( useActDamage ) {
                    defenses.z = (integer)defenses.z & ~PEACE_MASK;
                } else {
                    defenses.z = (integer)defenses.z | PEACE_MASK;
                }
                store( defenses, DEFENSES );
            } else if ( cmd == "smesg" ) {
                statusMsg = !statusMsg;
                if ( statusMsg ) llOwnerSay( 
                    "Reporting Morale & Focus changes." );
                else llOwnerSay(
                    "Status messages muted." );
            } else if ( cmd == "mygrp" ) {
                sameGroupOnly = !sameGroupOnly;
                if ( sameGroupOnly ) {
                    llOwnerSay( "Act! will only interact with people in your active group." );
                } else {
                    llOwnerSay( "Interacting with everyone." );
                }
            } else if ( cmd == "amenu" ) {
                vector defenses = retrieve( DEFENSES );
                string my_menuItems = menuItems;
                string my_menuCommands = menuCommands;
                if ( (integer)defenses.z & SEX_MASK ) {
                    my_menuItems += ", Sex Act! Off";
                } else {
                    my_menuItems += ", Sex Act! On";
                }
                my_menuCommands += ", act!§actmode";
                llMessageLinked( menuPrim, RP_MASK, 
                    llDumpList2String( [ "menu", "Act! Menu",
                        my_menuItems, my_menuCommands ], LINK_DELIM ),
                    id );
            } else if ( cmd == "point" ) {
                key target = get_target();
                if ( target ) {
                    llMessageLinked( commPrim, COMM_MASK,
                        llDumpList2String(
                            [ "xcmd", "play", "shoot", 0.0, target ],
                            LINK_DELIM ),
                        llGetOwner() );
                }
            } else if ( cmd == "actmode") {
                toggle_act_mode();
            }
        } else if ( cmd == "rset" ) {
            llSleep( 5.0 );
            llResetScript();
        } else if ( cmd == "diag" ) {
            llWhisper( 0, "/me ACT! RESOURCE TRACKER\n" +
                (string)llGetFreeMemory() + " bytes free" +
                "\nACT! channel: " + (string)myChannel +
                "\nRDI: " + (string)retrieve(RDI) + 
                "\nSMF:" + (string)retrieve(SMF) +
                "\nDefenses: " + (string)retrieve(DEFENSES) +
                "\nRecovery: " + (string)retrieve(RECOVERY) );
        }
    }
}
// ===========================================================================
// The damage field:
// Action damage notation
// |     Damage
// |     |   prep time
// |     |   |           Defense bonus modifier
// |     |   |           |    Damage type
// |     |   |           |    |   8-bit integer for flags
// |     |   |           |    |   |           32-bit integer for effects
// |     |   |           |    |   |           Top 18 are hue start & end
// |     |   |           |    |   |           |
// |     |   |           |    |   |           |
// a!dmg:100:000000000.0:±000:cut:255:-2147483648
//
// Damage types:
//  cr = crushing, force
//  cut = cutting
//  pi = arrow, bullet (piercing)
//  tox = toxic, poison
//  brn = burning, fire, electricity, heat
//  cor = corrosive, acid
//  psy = psychic or psychological
//  drn = energy drain
//  sex = sexual arousal

// Damage flags
integer DAZED_MASK = 0x1;       // Target may lose all defense bonus
integer STUN_MASK = 0x2;        // Target becomes unable to act
integer RESTRAIN_MASK = 0x4;    // Target becomes unable to move
// integer 0x8                     Unused
integer KNOCKBACK_MASK = 0x10;  // Target moves away from attacker
integer THREAT_MASK = 0x20;     // Target switches target to attacker
integer WOUND_MASK = 0x40;      // Target's recovery reduced
// integer 0x80                    Unused
integer SUPER_MASK = 0x100;     // Damage penetrates invulnerability

take_damage( list damage, key id )       // Process taking damage
{
    if ( get_flag( PEACE_MASK ) ) return;
    vector defense = retrieve( DEFENSES );
    vector attributes = retrieve( RDI );
    vector resources = retrieve( SMF );
    vector recovery = retrieve( RECOVERY );
    float now = llGetTime();
    // Extract damage
    float dmg = (float)llList2String( damage, 0 ); 
    integer statusOnly = dmg < 0.0;
    dmg = llFabs( dmg );
    
    // llOwnerSay( "dmg = " + (string)dmg );
    
    integer attackFlags = (integer)llList2String( damage, 4 );
    integer statusFlags = (integer)resources.x;
    integer defenseFlags = (integer)defense.z;
    
    if ( defenseFlags & TURN_MASK ) {
        if ( llSubStringIndex( attackers, (string)id ) > -1 ) {
            if ( statusFlags & STUNNED_MASK ) {
                llMessageLinked( LINK_THIS, RP_MASK, "act!" + LINK_DELIM +    
                    "turn", llGetOwner() );
            } else {
                llRegionSayTo( llGetOwnerKey(id), 0, "Already attacked " +
                    "secondlife:///app/agent/" + (string)llGetOwner() + "/info" );
                return;
            }
        } else {
            attackers += ":" + (string)id;
            if ( llStringLength( attackers ) > 259 ) {
                attackers = llGetSubString( attackers, 37, -1 );
            }
        }
    }
    
    if ( defenseFlags & INVULNERABLE_MASK ) {
        if ( !( attackFlags & SUPER_MASK ) ) {
            return;
        }
    }
    if ( !( statusFlags & VULNERABLE_MASK ) ) 
    {                                   // No defense if vulnerable
        float dodgeChance = ( attributes.z *
            llListStatistics( LIST_STAT_MIN, [ now - lastDodge, 1.0 ] ) );
        float dodgeRoll = llFrand( 65.0 );
        //llOwnerSay( "dodgeChance = " + (string)dodgeChance +
        //    "; dodgeRoll = " + (string)dodgeRoll );
        if ( dodgeChance >= dodgeRoll ) 
        {                                           // Successful defense roll
            defense.x += attributes.x;              // Add resiliance to DB
            llOwnerSay( "Defended!" );
            if ( !( llGetAgentInfo( llGetOwner() ) & AGENT_SITTING ) ) {
                llWhisper( power_channel( llGetOwner() ), llDumpList2String(
                    [ llGetOwner(), "play", "defend", 0.25 ], CHAT_DELIM ) );
            }
            if ( defenseFlags & DEFENDING_MASK ) {
                float focusBonus = recovery.x * DODGE_FOCUS_MULT *
                    llListStatistics( LIST_STAT_MIN, [ now - lastDodge, 1.0 ] );
                resources.z += focusBonus;
                if ( statusMsg ) {
                    llOwnerSay( "Focus +" + (string)llRound(focusBonus) );
                }
            }
            
        }
        lastDodge = now;
        if ( defenseFlags & DEFENDING_MASK )        // Halve damage if actively
        {                                           // defending
            defense.x += DB_DENOMINATOR;
        }
    }
    defense.x += (float)llList2String( damage, 2 ); // Apply attack DB modifier
    if ( defense.x < 0.0 ) defense.x = 0.0;

    string type = llList2String( damage, 3 );
    string params = llList2String( damage, 5 );
    
    // Shield damage
    if ( shield ) {
        // Inflict damage on shield
        llRegionSay( key2channel( llList2Key( shield, 0 ) ),
            llDumpList2String( [ llList2Key( shield, 0 ), "a!dmg", 
                    dmg * ( 1.0 - llList2Float( shield, 1 ) ) ] + 
                    llList2List( damage, 1, 3 ) + [ 0 ] +
                    llList2List( damage, 5, -1 ), 
                ACT_DELIM ) 
            );
        dmg *= llList2Float( shield, 1 );
    }
    // Apply armor
    if ( (float)llList2String( damage, 1 ) > -1.0 ) {
        dmg -= ( defense.y / ( (float)llList2String( damage, 1 ) + 1.0 ) );
    }
    // Apply defense bonus
    //llOwnerSay( "DB = " + (string)defense.x + "; Defense = " + (string)llPow( 2.0, ( defense.x ) / DB_DENOMINATOR ) );
    dmg /=  llPow( 2.0, ( defense.x ) / DB_DENOMINATOR );
    
    //llOwnerSay( "Final dmg = " + (string)dmg );    
                
    // Finally, actually take damage
    if ( dmg >= 0 ) {
        float statusUntil = FALSE;
        if ( !statusOnly ) {
            if ( type == "drn" ) {
                resources.z -= dmg;
                if ( statusMsg ) {
                    llOwnerSay( "Focus −" + (string)llRound(dmg) );
                }
            } else {
                resources.y -= dmg;
                if ( statusMsg ) {
                    llOwnerSay( "Morale -" + (string)llRound(dmg) );
                }
            }
            statusUntil = now + ( dmg / 2.0 );
        } else {
            statusUntil = now + ( dmg );
        }
        
        // Status effects for turn-based action
        if ( ( defenseFlags & TURN_MASK ) && !statusOnly ) {
            float resistRoll = llFrand( 65.0 );
            // llOwnerSay( "resistRoll=" + (string)resistRoll +
            //    "; resilience=" + (string)attributes.x );
            if ( resistRoll <= attributes.x ) {
                if ( attackFlags ) llOwnerSay( "Resisted status effects" );
                attackFlags = FALSE;
            }
        }
        
        // Apply status effects
        if ( ( dmg >= attributes.x / 2.0 ) ||
            ( attackFlags & STUN_MASK ) ) // Inflict stunned result
        {
            statusFlags = statusFlags | STUNNED_MASK;
            stunnedUntil = llListStatistics( LIST_STAT_MAX,
                [ stunnedUntil, statusUntil ] );
            if ( !( defenseFlags & TURN_MASK ) ) {
                llMessageLinked( LINK_ROOT, UI_MASK, 
                    llDumpList2String( ["busy", stunnedUntil - now ],
                        LINK_DELIM ),
                    llGetOwner() );
            }
            attackers = "";
        }
        if ( attackFlags & WOUND_MASK ) {
            statusFlags = statusFlags | WOUNDED_MASK;
            woundedUntil = llListStatistics( LIST_STAT_MAX,
                [ woundedUntil, statusUntil ] );
        }
        if ( attackFlags & DAZED_MASK ) {
            statusFlags = statusFlags | VULNERABLE_MASK;
            vulnerableUntil = llListStatistics( LIST_STAT_MAX,
                [ vulnerableUntil, statusUntil ] );
        }
        if ( attackFlags & RESTRAIN_MASK ) {
            statusFlags = statusFlags | RESTRAINED_MASK;
            restrainedUntil = llListStatistics( LIST_STAT_MAX,
                [ restrainedUntil, statusUntil ] );
        }
        if ( attackFlags & THREAT_MASK ) // -- Switch targets if threatened
        {
            llMessageLinked( LINK_ALL_OTHERS, BROADCAST_MASK, 
                llDumpList2String( [ "trgt", id ], LINK_DELIM ),
                llGetKey() );
            llWhisper( key2channel( llGetOwner() ),
                llDumpList2String( [ llGetOwner(), "a!tgt", llGetOwnerKey(id) ], 
                    ACT_DELIM ) 
                );
        }
    }
    
    update_resources( <statusFlags, resources.y, resources.z> );
}

set_restrained( integer root )
{
    if ( useActDamage ) {
        if ( llGetPermissions() & PERMISSION_TAKE_CONTROLS ) {
            llTakeControls( CONTROL_FWD | CONTROL_BACK | 
               CONTROL_UP | CONTROL_DOWN |
               CONTROL_LEFT | CONTROL_RIGHT | 
               CONTROL_ROT_LEFT | CONTROL_ROT_RIGHT,
               root, !root );
        } else {
            llRequestPermissions( llGetOwner(), PERMISSION_TAKE_CONTROLS );
        }
    }
}

set_stunned( integer stun )
{
    if ( useActDamage ) {
        if ( stun ) {
            llMessageLinked( LINK_ROOT, RP_MASK, "busy" + LINK_DELIM +
                "60.0", llGetKey() );
        } else {
            llMessageLinked( LINK_ROOT, RP_MASK, "busy" + LINK_DELIM +
                "0.0", llGetKey() );
        }
        if ( llGetPermissions() & PERMISSION_TAKE_CONTROLS ) {
            llTakeControls( CONTROL_LBUTTON | CONTROL_ML_LBUTTON,
                stun, !stun );
        }
    }
}

use_focus( list drain )                     // Expend power for abilities
{
    if ( get_flag( PEACE_MASK ) ) return;
    vector resources = retrieve( SMF );
    float ergs = (float)llList2String( drain, 0 );
    resources.z -= ergs;
    if ( ergs < 0 ) {
        vector rdi = retrieve( RDI );
        if ( llFabs( ergs ) > rdi.z ) {
            ergs = -1.0 * rdi.z;
        }
    }
    // llOwnerSay( "ERGS = " + (string)ergs );
    update_resources( resources );
    if ( statusMsg ) {
        if ( ergs > 0.0 ) {
            llOwnerSay( "Focus -" + (string)llRound( ergs ) );
        } else {
            llOwnerSay( "Focus: +" + (string)llRound( -ergs ) );
        }
    }
}

/* 
set_flag( integer mask )                    // Set a status flag
{
    vector flags = retrieve( DEFENSES );
    if ( !( (integer)flags.z & mask ) ) {
        flags.z = (integer)flags.z | mask;
        store( flags, DEFENSES );
    }
} 
*/

integer get_flag( integer mask )
{
    vector flags = retrieve( DEFENSES );
    return (integer)flags.z & mask;
}

clear_flag( integer mask )                  // Clear a status flag
{
    vector flags = retrieve( DEFENSES );
    if ( (integer)flags.z & mask ) {
        flags.z = (integer)flags.z ^ mask;
        store( flags, DEFENSES );
    }
}

update_resources( vector resources )        // Clamp and update resources
{
    vector rec = retrieve( RECOVERY );

    if ( resources.y < 0.0 )
    {
        resources.y = 0.0;
        resources.x = (integer)resources.x | DEFEATED_MASK;
    }
    if ( resources.z < 0 ) {
        rec.y += resources.z;
        resources.z = 0.0;
        if ( rec.y <= 0.0 ) {
            resources.x = (integer)resources.x | DEFEATED_MASK;
        }
        if ( rec.y < 0.0 ) rec.y = 0.0;
        store( rec, RECOVERY );
    }
    if ( resources.z > rec.y ) {
        resources.z = rec.y;
    }
    if ( llVecDist( resources, retrieve( SMF ) ) > 0.1 ) {
        store( resources, SMF );
    }
}

resting_recovery()                          // Periodic recovery & housekeeping
{
    vector resources = retrieve( SMF );
    vector rec = retrieve( RECOVERY );
    vector attributes = retrieve( RDI );
    vector defenses = retrieve( DEFENSES );
    vector needs = retrieve( NEEDS );
    vector baseAttributes = llList2Vector( llGetLinkPrimitiveParams( LINK_THIS, 
        [ PRIM_POINT_LIGHT ] ), 1 ) * 0xFF;
    float now = llGetTime();
    
    integer status = (integer)resources.x;
    float scale = 5.0;
    //if ( (integer)defenses.z & COMBAT_MASK ) {
    //    scale = 1.0;
    //}

    // Remove conditions here
    if ( ( status & STUNNED_MASK ) && 
        (( now > stunnedUntil ) || ( (integer)defenses.z & TURN_MASK )) ) {
        status = status & ~STUNNED_MASK;
        llMessageLinked( LINK_ROOT, UI_MASK, "unbusy", llGetOwner() );
    }
    if ( ( status & WOUNDED_MASK ) && ( now > woundedUntil ) ) {
        status = status & ~WOUNDED_MASK;
    }
    if ( ( status & VULNERABLE_MASK ) && ( now > vulnerableUntil ) ) {
        status = status & ~VULNERABLE_MASK;
    }
    if ( ( status & RESTRAINED_MASK ) && ( now > restrainedUntil ) ) {
        status = status & ~RESTRAINED_MASK;
    }
    if ( ( (integer)defenses.z & INVULNERABLE_MASK ) && 
        ( now > invulnerableUntil ) ) 
    {
        defenses.z = (float)( (integer)defenses.z & ~INVULNERABLE_MASK );
        store( defenses, DEFENSES );
    }
    
    if ( now > damageBuffUntil ) {
        store( ZERO_VECTOR, COMBAT );
    }
    
    // Recover attributes
    if ( llVecDist( attributes, baseAttributes ) > 0.1 ) {
        if ( baseAttributes.x > attributes.x && ( status ^ WOUNDED_MASK )) {
            attributes.x = llListStatistics( LIST_STAT_MIN,
                [ baseAttributes.x, attributes.x + ( scale / 5.0 ) ] );
        } else if ( baseAttributes.x < attributes.x ) {
            attributes.x = llListStatistics( LIST_STAT_MAX,
                [ baseAttributes.x, attributes.x - ( scale / 5.0 ) ] );
        }
        if ( baseAttributes.y > attributes.y && ( status ^ WOUNDED_MASK )) {
            attributes.y = llListStatistics( LIST_STAT_MIN,
                [ baseAttributes.y, attributes.y + ( scale / 5.0 ) ] );
        } else if ( baseAttributes.y < attributes.y ) {
            attributes.y = llListStatistics( LIST_STAT_MAX,
                [ baseAttributes.y, attributes.y - ( scale / 5.0 ) ] );
        }
        if ( baseAttributes.z > attributes.z && ( status ^ WOUNDED_MASK )) {
            attributes.z = llListStatistics( LIST_STAT_MIN,
                [ baseAttributes.z, attributes.z + ( scale / 5.0 ) ] );
        } else if ( baseAttributes.x < attributes.x ) {
            attributes.z = llListStatistics( LIST_STAT_MAX,
                [ baseAttributes.z, attributes.z - ( scale / 5.0 ) ] );
        }
        store( attributes, RDI );
    }

    // Set focus
    float oFocus = resources.z;
    if ( resources.z < attributes.y && ( status ^ WOUNDED_MASK ) 
        && !( (integer)defenses.z & COMBAT_MASK ) ) {
        resources.z += llListStatistics( LIST_STAT_MAX, 
            [ 0, rec.x * scale ] );
        if ( resources.z > attributes.y ) {
            resources.z = attributes.y;
        }
    } else if ( resources.z > attributes.y ) {
        resources.z -= scale * 0.2;
        if ( resources.z < attributes.y ) {
            resources.z = attributes.y;
        }
    }
    // llOwnerSay( llGetScriptName() + ": Focus delta " 
    //    + (string)( resources.z - oFocus ) );
    
    // Set morale
    if ( attributes.y + attributes.x - resources.y > 0.1 && 
        ( status ^ WOUNDED_MASK )) 
    {
        resources.y += llListStatistics( LIST_STAT_MAX,
            [ 0, llFloor( rec.z * scale ) ] );
    }
    if ( resources.y - attributes.x - attributes.y > 0.1 ) {
        resources.y = attributes.x + attributes.y;
    }
    
    if ( rec.y < ( attributes.y + attributes.z ) && 
        ( status ^ WOUNDED_MASK )) 
    {
        rec.y += ( attributes.y + attributes.z ) * 0.001 * scale;
        if ( rec.y > ( attributes.y + attributes.z ) ) {
            rec.y = ( attributes.y + attributes.z );
        }
        store( rec, RECOVERY );
    }
    
    if ( needs.y > 0.0 ) {
        needs.y = needs.y - 0.1 * scale;
        store( needs, NEEDS );
    }
    
    attackers = "";    
    update_resources( <status, (integer)resources.y, (integer)resources.z > );
    llSetTimerEvent( scale );
}

toggle_act_mode() {
    vector defenses = retrieve( DEFENSES );
    defenses.z = (integer)defenses.z ^ SEX_MASK;
    store( defenses, DEFENSES );
    key texture = ACT_ICON;
    if ( (integer)defenses.z & SEX_MASK ) {
        texture = SEX_ACT_ICON;
    }
    llSetLinkPrimitiveParamsFast( actMenuPrim,
        [ PRIM_TEXTURE, DISPLAY_FACE, texture, <1, 1, 1>, 
            ZERO_VECTOR, 0.0 ]
        );
}
// ===========================================================================
// Basic Act! functions

integer targetPrim;                     // Where to store targets

pong()
{
    llRegionSay( myChannel, 
        llDumpList2String( [ "a!smf", 
            llGetColor( SMF ) * 0xFF,
            llGetColor( RDI ) * 0xFF,
            llGetColor( DEFENSES ) * 0xFF,
            llGetColor( COMBAT ) * 0xFF,
            llGetColor( RECOVERY ) * 0xFF,
            llGetColor( NEEDS ) * 0xFF ]
        , ACT_DELIM ) );
}

set_target( key id )
{
    llSetLinkPrimitiveParamsFast( targetPrim,
        [ PRIM_DESC, (string)id ] );
    llMessageLinked( LINK_ALL_OTHERS, BROADCAST_MASK, 
        llDumpList2String( [ "trgt", id ], LINK_DELIM ),
        llGetKey() );
}

key get_target()
{
    return (key)llList2String(
        llGetLinkPrimitiveParams( targetPrim, [ PRIM_DESC ] ), 0 );
}

// ===========================================================================
// Functions to store/retrieve attribute values

store( vector store, integer face )
{
    store /= 0xFF;
    if ( llGetColor( face ) != store ) {
        llSetColor( store, face );
    }
}

vector retrieve( integer face )
{
    return llGetColor( face ) * 0xFF;
}

integer LIT_FACE = 0;
integer DIM_FACE = 2;

set_prim_lit( integer prim, integer lit )
{
    if ( prim < 2 ) return;
    if ( lit ) {
        llSetLinkColor( prim, 
            llList2Vector( 
                llGetLinkPrimitiveParams( LINK_ROOT, 
                    [ PRIM_COLOR, LIT_FACE ] )
                , 0 ), 
            ALL_SIDES );
    } else {
        llSetLinkColor( prim, 
            llList2Vector( 
                llGetLinkPrimitiveParams( LINK_ROOT, 
                    [ PRIM_COLOR, DIM_FACE ] )
                , 0 ), 
            ALL_SIDES );
    }
}

list get_link_numbers_for_names(list namesToLookFor)
{
    list linkNumbers = namesToLookFor;
    integer f = llGetNumberOfPrims();
    integer pos = -1;
    do {
        pos = llListFindList(namesToLookFor, [llGetLinkName(f)]);
        if (pos > -1) {
            linkNumbers = llListReplaceList(linkNumbers, [f], pos, pos);
        }
    } while (--f > 0);
    return linkNumbers;
}

// =========================================================================
// Communications functions
// =========================================================================

string CHAT_DELIM = "|";
string ACT_DELIM = ":";
string LINK_DELIM = "§";
integer RP_MASK             = 0x4000000;
integer BROADCAST_MASK      = 0xFFF00000;
integer UI_MASK             = 0x80000000;
integer COMM_MASK           = 0x10000000;
integer CMBT_MASK           = 0x8000000;

integer myChannel;                      // My listener channel
integer myListen;                       // Unique listener
string myHeader;                        // Header for messages sent to me

string ownerHit;                        // Listen prefix for damage
string NO_DAMAGE = "";                  // No damage pending

string menuItems = "Reload, Statistics, Say Status";
string menuCommands = "act!§char, act!§stat, act!§smesg";

integer key2channel( key who ) {
    return -1 * (integer)( "0x" + llGetSubString( (string)who, -12, -5 ) );
}
    
integer power_channel( key who ) {
    return -1 *
        (integer)( "0x" + llGetSubString( (string)who, -10, -3 ) );
}

// ===========================================================================

default
{
    state_entry()
    {
        llSetRemoteScriptAccessPin( 0 );
        myHeader = (string)llGetOwner() + ACT_DELIM;
        myChannel = key2channel( llGetOwner() );
        
        list prims = get_link_numbers_for_names( 
            ["combat", "target", 
            "teamList", "menu", "act!^peace",
            "act!:amenu" ] );
        combatPrim = llList2Integer( prims, 0 );
        targetPrim = llList2Integer( prims, 1 );
        teamPrim = llList2Integer( prims, 2 );
        menuPrim = llList2Integer( prims, 3 );
        peacePrim = llList2Integer( prims, 4 );
        actMenuPrim = llList2Integer( prims, 5 );
        
        set_prim_lit( peacePrim, !useActDamage );
        set_target( NULL_KEY );
        
        clear_flag( TURN_MASK );
        clear_flag( COMBAT_MASK );
        
        vector srp = retrieve( SMF );
        update_resources( < 0.0, srp.y, srp.z > );
        if ( llGetAttached() )
        {
            llRequestPermissions( llGetOwner(), PERMISSION_TAKE_CONTROLS );
            myListen = llListen( myChannel, "", NULL_KEY, "" );
            llSetTimerEvent( 5.0 );
        }
        /* llSay( DEBUG_CHANNEL, llGetScriptName() + " started " +
            (string)llGetFreeMemory() + " bytes free." ); */
        toggle_act_mode();
    }
    
    attach( key id )
    {
        if ( id )
        {
            llRequestPermissions( id, PERMISSION_TAKE_CONTROLS );
            set_target( NULL_KEY );
            llSetTimerEvent( 5.0 );
        }
    }
    
    run_time_permissions( integer perm )
    {
        if ( perm & PERMISSION_TAKE_CONTROLS ) {
            set_restrained( FALSE );
        }
    }
        
    on_rez( integer p )
    {
        llResetScript();
    }
    
    changed( integer change )
    {
        if ( change & CHANGED_COLOR )
        {
            vector srp = retrieve( SMF );
            integer states = (integer)srp.x;
            if ( ( states & DEFEATED_MASK ) && useActDamage ) {
                state defeated;
            }
            if ( ( states & COMBAT_MASK ) && !inCombat ) {
                inCombat = TRUE;
                lastDodge = llGetTime();
            } else if ( !( states & COMBAT_MASK ) && inCombat ) {
                inCombat = FALSE;
            }
            pong();
        } else if ( change & CHANGED_OWNER || 
            change & CHANGED_INVENTORY || 
            change & CHANGED_ALLOWED_DROP ) 
        {
            llResetScript();
        }    
    }
    
    listen( integer channel, string who, key id, string heard )
    {
        //llOwnerSay( llGetScriptName() + " heard " + who + " say on channel " + (string)channel + ": " + heard );
        if ( channel == myChannel ) {
            if ( llGetSubString( heard, 0, 36 ) == myHeader ) {
                heard = llGetSubString( heard, 37, -1 );
                string cmd = llGetSubString( heard, 0, 4 );
                
                // llOwnerSay( llGetScriptName() + " acting on " + cmd );
                
                if ( cmd == "a!hit" ) {
                    // I got hit!
                    string dmg = llList2String( 
                        llGetLinkPrimitiveParams(
                            combatPrim, [ PRIM_DESC ] )
                        , 0 );
                    if ( dmg != NO_DAMAGE ) {
                        key hit = (key)llGetSubString( heard, 6, -1 );
                        llRegionSay( key2channel( hit ),
                            llDumpList2String( [ hit, dmg ], 
                                ACT_DELIM ) 
                            );
                    }
                } else if ( cmd == "a!cwp" || cmd == "a!rwp" ) {
                    // Change of close or ranged weapon
                    list msg = [ "cmbt", "wpns" ];
                    if ( cmd == "a!cwp" ) msg += [ "melee" ];
                    else msg += [ "range" ];
                    msg += llParseString2List( 
                        llGetSubString( heard, 6, -1 ),
                        [ACT_DELIM], [] );
                    llMessageLinked( combatPrim, CMBT_MASK,
                        llDumpList2String( msg, LINK_DELIM ),
                        id );
                } else if ( cmd == "a!tgt" ) {
                    // Retarget
                    set_target( (key)llGetSubString( heard, 6, -1 ) );
                } else if ( cmd == "a!png" ) {
                    // Respond to ping with character sttus
                    pong();
                } else if ( cmd == "a?tgt" ) {
                    // Who's my target?
                    llRegionSay( myChannel, 
                        llDumpList2String( 
                            [ llGetOwner(), "a!tgt", get_target() ]
                            , ACT_DELIM ) );
                } else {
                    // Pass on to other scripts
                    llMessageLinked( LINK_THIS, RP_MASK, 
                        llDumpList2String( [ "act!" ] + [ heard ],
                            LINK_DELIM ),
                        id );
                }
            }
        }
    }
    
    link_message( integer sender, integer signal, string msg, key id )
    {
        handle_command( sender, signal, msg, id );
    }
    
    timer()
    {
        if ( !get_flag( TURN_MASK ) ) {
            resting_recovery();
        }
    }
}

state defeated
{
    state_entry()
    {
        llSetTimerEvent( KO_TIME );
        set_stunned( TRUE );
        set_restrained( TRUE );
        vector rec = retrieve( RECOVERY );
        string name = llGetObjectDesc() + " (" + 
            llGetUsername( llGetOwner() ) + ") ";
        if ( rec.y == 0.0 ) {
            llSay( 0, name + "is exhausted and has been defeated." );
        } else {
            llSay( 0, name + "is demoralized and has been defeated." );
        }
        vector smf = retrieve( SMF );
        integer states = (integer)smf.x | STUNNED_MASK | RESTRAINED_MASK | 
            DEFEATED_MASK;
        store( <states, 1.0, 1.0>, SMF );
        
        llWhisper( power_channel( llGetOwner() ),
            llDumpList2String( [ "play", "defeated", KO_TIME ], CHAT_DELIM ) );
    }
        
    link_message( integer sender, integer signal, string msg, key id )
    {
        handle_command( sender, signal, msg, id );
    }
        
    timer()
    {
        vector smf = retrieve( SMF );
        store( <(integer)smf.x & ~DEFEATED_MASK, smf.y, smf.z>, SMF );
    }
    
    changed( integer change )
    {
        if ( change & CHANGED_COLOR )
        {
            vector srp = retrieve( SMF );
            integer states = (integer)srp.x;
            if ( !( states & DEFEATED_MASK ) ) {
                state default;
            }
        }
    }
    
    state_exit()
    {
        llSetTimerEvent( 0. );
        
        llWhisper( power_channel( llGetOwner() ),
            llDumpList2String( [ "play", "defeated end", 0.0 ], CHAT_DELIM ) );

        llSay( 0, llGetObjectDesc() + " (" + 
            llGetUsername( llGetOwner() ) + ") rallies." );
    }
}
