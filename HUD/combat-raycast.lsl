// =========================================================================
// Combat controller                                                       \
// By Jack Abraham                                                      \__
// =========================================================================

integer attackMode;
integer autoAim = TRUE;

float DB_DENOMINATOR = 32.0;            // This much DB gives 2× protection

float MINIMUM_ATTACK_TIME = 1.0;        // Minimum time between attacks
float TIMER_FUDGE = 0.1;                // Fudge factor for execution delay
                                        // in autoattack timers

float meleeRange = 2.0;                 // Reach for melee attacks
float MELEE_RANGE_DEFAULT = 2.0;        // What to use if unspecified
float rangeRange = 20.0;                // Range for ranged attacks
float RANGE_DEFAULT = 20.0;             // What to use if unspecified, again

integer autoAttack = FALSE;             // Execute autoattacks
integer autoAttackSuspend = FALSE;      // Temporarilly interrupt autoattacks
float autoAttackRate = 1.0;             // How often to autoattack

string NO_DAMAGE = "";                  // No damage pending

key meleeWeapon = NULL_KEY;
list meleeWeaponStats;
float meleeDelay;
key rangeWeapon = NULL_KEY;
list rangeWeaponStats;        
float rangeDelay;

integer rangedModePrim = LINK_SET;
integer rangedModeMask = 0x2000000;
string rangedModeCommand = "objt§stmn§ranged";
integer meleeModePrim = LINK_SET;
integer meleeModeMask = 0x2000000;
string meleeModeCommand = "objt§stmn§melee";
integer defenseModePrim = LINK_SET;
integer defenseModeMask = 0x2000000;
string defenseModeCommand = "objt§stmn§shield";

// =========================================================================

integer attack( integer controls )
{
    if ( can_attack() ) {
        key target = get_target();
        if ( target ) {
            vector to = vector_to( target );
            if ( to.x >= 0.0 ) {
                float range = llVecMag( to );
                if ( range <= meleeRange ) {
                    return melee_attack( controls, target );
                } else if ( range < rangeRange ) {
                    return ranged_attack( controls, target );
                }
            } else if ( llKey2Name( target ) ) {
                llOwnerSay( "Must face target." );
                return FALSE;
            }
        } else if ( autoAim ) {
            llSensor( "", NULL_KEY, AGENT | ACTIVE | PASSIVE, 
                meleeRange, PI_BY_TWO );
            return FALSE;
        } else {
            return ranged_attack( controls, NULL_KEY );
        }
    }
    return FALSE;
}

vector RAYCAST_OFFSET = <0., 0., 0.5>;

list check_line_of_sight( key id )
{
    vector here = llGetPos() + RAYCAST_OFFSET;
    vector there;
    if ( id != NULL_KEY ) {
        there = llList2Vector( llGetObjectDetails( id,
            [ OBJECT_POS ] ), 0 );
    } else {
        there = here + ( <20, 0, 0> * llList2Rot( llGetObjectDetails( llGetOwner(),
            [OBJECT_ROT] ), 0 ) );
    }
        
    list hit = [];
    vector impact;
    list cast;
    integer noHit = 3;
    do {
        list cast = llCastRay( here,
            here + ( llVecNorm( there - here ) * rangeRange ),
            [ RC_REJECT_TYPES, RC_REJECT_LAND, RC_MAX_HITS, 1,
                RC_DATA_FLAGS, RC_GET_ROOT_KEY ]
            );
            
        integer status = llList2Integer( cast, -1 );
        if ( status > -1 ) {
            //llOwnerSay( llKey2Name(llList2Key( cast, 0 )) + "@" +
            //    (string)llList2Vector( cast, 1 ) );
            // We hit something (if land, hit == NULL_KEY )
            noHit = FALSE;
            hit = llList2List( cast, 0, 1 );
        } else if ( status ) {
            --noHit;
            llSleep( 0.05 );
        }
    } while ( noHit );
    
    return hit;
}

raycast_attack( key id )
{
    id = llList2Key( check_line_of_sight( id ), 0 );
    if ( id != NULL_KEY ) {
        vector to =  llList2Vector( llGetObjectDetails( id,
            [ OBJECT_POS ] ), 0 ) - llGetPos();
        float range = llVecMag( to );
        if ( range <= meleeRange ) {
            send_damage( id, meleeWeaponStats );
        } else if ( range < rangeRange ) {
            send_damage( id, rangeWeaponStats );
        }
    }
}

send_damage( key target, list damage )
{
    if ( target ) {
        llRegionSay( key2channel( target ),
            llDumpList2String( [ target,  "a!dmg" ] 
                + damage, ACT_DELIM ) );
    }
    malthusan_damage( target, meleeWeaponStats );
}

integer melee_attack( integer controlled, key target )
{
    if ( llKey2Name( meleeWeapon ) ) {
        vector smf = retrieve( SMF );
        float focus = get_focus( llListStatistics( LIST_STAT_MIN,
                [ llGetTime(), meleeDelay ] ),
            meleeWeaponStats, controlled );
        if ( smf.z < 1.0 && focus > 0.0 ) {
            return FALSE;
        }
        if ( llListFindList( get_team(), [ (string)target ] ) != -1 ) {
            return FALSE;
        }
        if ( !controlled ) {
            llWhisper( actChannel, "a!cat" );
        }
        send_damage( target, meleeWeaponStats );
        llMessageLinked( actPrim, RP_LINK_MASK, llDumpList2String( 
            [ "act!", "a!fcs", focus ], LINK_DELIM ), 
            llGetOwner() );
        llResetTime();
        return TRUE;
    }
    if ( meleeWeapon ) {
        meleeWeapon = NULL_KEY;
    }
    if ( meleeWeapon == NULL_KEY ) {
        llWhisper( key2channel( llGetOwner() ), "a!inv" );
    }
    return FALSE;
}

integer ranged_attack( integer controlled, key target )
{
    if ( llKey2Name( rangeWeapon ) ) {
        vector smf = retrieve( SMF );
        float focus = get_focus( llListStatistics( LIST_STAT_MIN,
                [ llGetTime(), rangeDelay ] ),
            rangeWeaponStats, controlled );
        if ( smf.z < 1.0 && focus > 0.0 ) {
            return FALSE;
        }
        if ( llListFindList( get_team(), [ (string)target ] ) != -1 ) {
            return FALSE;
        }
        vector impact = ZERO_VECTOR;
        // Always trigger the shoot sfx
        list cast =  check_line_of_sight( target );
        if ( cast != [] ) {
            target = llList2Key( cast, 0 );
            impact = llList2Vector( cast, 1 );
        }
        llWhisper( actChannel, 
            llDumpList2String( [ llGetOwner(), "a!rat", target, impact ],
                ACT_DELIM ) );
        send_damage( target, rangeWeaponStats );
        llMessageLinked( actPrim, RP_LINK_MASK, llDumpList2String( 
            [ "act!", "a!fcs", focus ], LINK_DELIM ), 
            llGetOwner() );

        llResetTime();
        
        // Re-target if manual
        
        if ( controlled ) {
            if ( target != get_target() ) {
                set_target( target );
            }
        }
        return TRUE;
    }
    if ( rangeWeapon ) {
        rangeWeapon = NULL_KEY;
    }
    if ( rangeWeapon == NULL_KEY ) {
        llWhisper( key2channel( llGetOwner() ), "a!inv" );
    }
    return FALSE;
}

manual_attack( integer ranged )
{
    autoAttackSuspend = TRUE;
    llSetTimerEvent( 0. );
    if ( ranged ) {
        set_combat_mode( RANGED );
        ranged_attack( TRUE, NULL_KEY );
    } else {
        set_combat_mode( MELEE );
        melee_attack( TRUE, NULL_KEY );
    }
    llResetTime();
    llSetTimerEvent( minimum_attack_time() );
    autoAttackSuspend = FALSE;
}


auto_attack()
{
    if ( !( llGetAgentInfo( llGetOwner() ) & AGENT_MOUSELOOK ) ) {
        attack( FALSE );
    }
    llSetTimerEvent( minimum_attack_time() );
}

integer can_attack()
{
    vector smf = retrieve( SMF );
    vector defenses = retrieve( DEFENSES );
    integer status = (integer)smf.x;
    integer states = (integer)defenses.z;
    if ( status & STUNNED_MASK || states & DEFENDING_MASK ) {
        llOwnerSay( "Cannot attack while stunned or defending." );
        return FALSE;
    } else if ( !( states & COMBAT_MASK ) ) {
        llOwnerSay( "Not in combat" );
        return FALSE;
    } else if ( (integer)llList2Float( 
        llGetLinkPrimitiveParams( LINK_ROOT, 
            [ PRIM_COLOR, DIM_FACE ] ), 1 ) ) 
    {
        llOwnerSay( "Busy." );
        return FALSE;
    }
    return TRUE;
}

float minimum_attack_time()
{
    if ( get_target() == NULL_KEY ) 
    {
        return autoAttackRate;
    }
    if ( range_to( get_target() ) <= meleeRange ) {
        if ( meleeDelay < autoAttackRate ) {
            return autoAttackRate;
        } else {
            return meleeDelay;
        }
    } else {
        if ( rangeDelay < autoAttackRate ) {
            return autoAttackRate;
        } else {
            return rangeDelay;
        }
    }
}

// =========================================================================
// Act! communications

integer actChannel;                     // Channel for Act! commands

integer key2channel( key who ) {
    return -1 * (integer)( "0x" + llGetSubString( (string)who, -12, -5 ) );
}

string rtCrypt(string str)
{
    return llXorBase64StringsCorrect(llStringToBase64(str),
        llStringToBase64(rtPassword));
}

float get_focus( float delay, list attack, integer manual ) {
    float dmg = (float)llList2Integer( attack, 0 );

    float dReuse = delay;

    float dmFlags = llPow( 1.5, bitcount( llList2Integer( attack, 4 ) ) - 1 );

    float prepTime = llList2Float( attack, 1 );
    float dTime = prepTime * 2.0;
    float dmTime = 1.5;
    if ( dmTime < 1.0 ) {
        dmTime = 0.5 + ( 1.0 / ( 1 + ( prepTime * prepTime ) ) );
    }
    
    float dmDB = 1.0;
    float DB = -1.0 * (float)llList2Integer( attack, 2 );
    if ( DB != 0.0 ) {
        dmDB = 1.0 + ( DB / DB_DENOMINATOR );
    }
    
    float autoAttackBonus = 0.0;
    if ( !manual ) {
        vector rec = retrieve( RECOVERY );
        autoAttackBonus = prepTime * rec.x;
    }
    
    return ( dmg / ( dmFlags * dmTime * dmDB ) ) 
        - dReuse - dTime - autoAttackBonus;
}

// Strife Onizuka rules, even if I don't end up needing this
integer bitcount(integer n)
{ //MIT Hackmem 169, modified to work in LSL
    integer tmp = n - ((n >> 1) & 0x5B6DB6DB) //modified mask
                    - ((n >> 2) & 0x49249249);
    return (((tmp + (tmp >> 3)) & 0xC71C71C7) % 63) - (n >> 31);
}

// =========================================================================
// Set combat modes

set_autoattack( integer on )
{
    autoAttack = on;
    set_prim_lit( autoAttackPrim, on );
    if ( on ) {
        llSetTimerEvent( minimum_attack_time() );
    } else {
        llSetTimerEvent( 0. );
    }
}

start_autoattack()
{
    autoAttackSuspend = TRUE;
    llSetTimerEvent( 0. );
    attack( FALSE );
    llResetTime();
    llSetTimerEvent( minimum_attack_time() );
    autoAttackSuspend = FALSE;
}

integer RANGED = 0x1;
integer MELEE = 0x2;
integer DEFEND = 0x4;
integer SAFE = 0x0;

set_combat_mode( integer mode )
{
    if ( mode == attackMode ) return;
    attackMode = mode;
    set_prim_lit( meleePrim, mode & MELEE );
    set_prim_lit( rangePrim, mode & RANGED );
    set_prim_lit( defensePrim, mode & DEFEND );
    set_prim_lit( attackPrim, mode & ( MELEE | RANGED ) );
    if ( mode & MELEE ) {
        llMessageLinked( meleeModePrim, meleeModeMask, meleeModeCommand,
            llGetOwner() );
    }
    if ( mode & RANGED ) {
        llMessageLinked( rangedModePrim, rangedModeMask, rangedModeCommand,
            llGetOwner() );
    }
    if ( mode & DEFEND ) {
        llMessageLinked( defenseModePrim, defenseModeMask, 
            defenseModeCommand, llGetOwner() );
    }
    vector defenses = retrieve( DEFENSES );
    if ( mode ^ DEFEND ) {
        defenses.z = (integer)defenses.z & ~DEFENDING_MASK;
    } else {
        defenses.z = (integer)defenses.z | DEFENDING_MASK;
    }
    store( defenses, DEFENSES );
    
//    if ( mode ) {
//        set_autoattack( mode ^ DEFEND );
//    }
}

set_default_combat_mode()
{
    key target = get_target();
    if ( target ) {
        float range = range_to( target );
        if ( range < meleeRange ) {
            set_combat_mode( MELEE );
            return;
        } else if ( range < rangeRange ) {
            set_combat_mode( RANGED );
            return;
        }
    }
    set_combat_mode( DEFEND );
}

// =========================================================================
// Get/set Act! data

integer actPrim;                        // prim with Act! parameters

// Values stored in faces:
//  Face 1: Resilience, Drive, Insight
integer RDI = 1;
//  Face 2: Damage status conditions, Morale, Focus
integer SMF = 2;
//  Face 3: Defense Bonus, Damage Resistance, Combat status conditions
integer DEFENSES = 3;
//  Face 4: Displayed face toward user; do not use
//  Face 5: Power recovery rate, Max Power, Resolve recovery rate
integer RECOVERY = 5;
// Face 6: Damage modifier, DB modifier, conditions mask
integer DAMAGE = 6;

// Bitmasks for states (resources.x)
integer STUNNED_MASK = 0x2;         // ⚠
integer RESTRAINED_MASK = 0x4;      // ⊗
integer DEFEATED_MASK = 0x8;        // ☠
integer WOUNDED_MASK = 0x10;        // ✚
integer VULNERABLE_MASK = 0x80;     //

// Bitmasks for combat status (defenses.z)
integer COMBAT_MASK = 0x01;         //
integer INVULNERABLE_MASK = 0x02;   //
integer DEFENDING_MASK = 0x04;      // 
integer PEACE_MASK = 0x08;          //

store( vector store, integer face )
{
    store /= 0xFF;
    list params = llGetLinkPrimitiveParams( actPrim, [ PRIM_COLOR, face ] );
    if ( llList2Vector( params, 0 ) != store ) {
        llSetLinkColor( actPrim, store, face );
    }
}

vector retrieve( integer face )
{
    vector value = llList2Vector( 
            llGetLinkPrimitiveParams( actPrim, [ PRIM_COLOR, face ] )
        , 0 )
        * 0xFF;
    return value;
}

// =========================================================================

integer menuPrim;
        
combat_menu()
{
    list items;
    if ( autoAim ) items += [ "Auto-Aim Off" ];
    else items += [ "Auto-Aim On" ];
    
    list cmds = ["cmbt§aaim" ];
    llMessageLinked( menuPrim, COMBAT_LINK_MASK,
        llDumpList2String( [ "menu",
            "Combat Options",
            llList2CSV( items ),
            llList2CSV( cmds ) ],
            LINK_DELIM ),
        llGetOwner() );
}

// =========================================================================
// Helpers

integer BROADCAST_MASK      = 0xFFF00000;
integer COMBAT_LINK_MASK    = 0x8000000;
integer CONSTRUCT_MASK      = 0x2000000;
integer RP_LINK_MASK        = 0x4000000;
string LINK_DELIM           = "§";
string CHAT_DELIM           = "|";
string ACT_DELIM            = ":";

integer constructPrim;
integer teamPrim;

float range_to( key target )
{
    vector here = llGetPos();
    vector there = llList2Vector(
        llGetObjectDetails( target, [ OBJECT_POS ] )
        , 0 );
    return llVecDist( here, there );
}

vector vector_to( key target )
{
    vector here = llGetPos();
    rotation rot = llList2Rot( 
        llGetObjectDetails( llGetOwner(), [ OBJECT_ROT ] ), 0 );
    vector there = llList2Vector(
        llGetObjectDetails( target, [ OBJECT_POS ] ), 0 );
    return ( there - here ) / rot;    
}

integer targetPrim = LINK_ROOT;

key get_target()
{
    return (key)llList2String(
        llGetLinkPrimitiveParams( targetPrim, [ PRIM_DESC ] ), 0 );
}

set_target( key id )
{
    llSetLinkPrimitiveParamsFast( targetPrim,
        [ PRIM_DESC, (string)id ] );
    llMessageLinked( LINK_SET, BROADCAST_MASK, 
        llDumpList2String( [ "trgt", id ], LINK_DELIM ),
        llGetKey() );
}

// Return a list of team members
list get_team()
{
    list team = llCSV2List( 
        llList2String( 
            llGetLinkPrimitiveParams( teamPrim, [ PRIM_TEXT ] ),
            0 )
        );
    return team;
}

// =========================================================================
// Control prim indicators

integer autoAttackPrim;
integer meleePrim;
integer rangePrim;
integer defensePrim;
integer attackPrim;

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

list get_link_numbers ( list names )
{
    integer c = llGetNumberOfPrims();
    integer i = -1;
    do {
        i = llListFindList( names, [ llGetLinkName( c ) ] );
        if ( i > -1 ) {
            names = llListReplaceList( names, [c], i, i );
        }
    } while ( c-- > 0 );
    return names;
}

default // ==== Initialization =============================================
{
    state_entry()
    {
        if ( !actPrim ) {
            list prims = get_link_numbers( [ "cmbt:auto", "cmbt:melee",
                "cmbt:ranged", "cmbt:defend", "Act!", "target",
                "construct", "menu", "attack", 
                "trgt:00000000-0000-0000-0000-000000000000" ] );
            autoAttackPrim = llList2Integer( prims, 0 );
            meleePrim = llList2Integer( prims, 1 );
            rangePrim = llList2Integer( prims, 2 );
            defensePrim = llList2Integer( prims, 3 );
            actPrim = llList2Integer( prims, 4 );
            targetPrim = llList2Integer( prims, 5 );
            constructPrim = llList2Integer( prims, 6 );
            rangedModePrim = llList2Integer( prims, 6 ); 
            meleeModePrim = llList2Integer( prims, 6 ); 
            defenseModePrim = llList2Integer( prims, 6 ); 
            menuPrim = llList2Integer( prims, 7 );
            attackPrim = llList2Integer( prims, 8 ); 
            teamPrim = llList2Integer( prims, 9 );
        }
        
        //set_autoattack( FALSE );
        autoAttackSuspend = FALSE;
        llSetObjectDesc( NO_DAMAGE );
        
        actChannel = key2channel( llGetOwner() );

        set_combat_mode( SAFE );
        
        if ( !( llGetPermissions() & PERMISSION_TAKE_CONTROLS ) ) {    
            llRequestPermissions( llGetOwner(), llGetPermissions() |
                PERMISSION_TAKE_CONTROLS );
        }
        
        vector defenses = retrieve( DEFENSES );
        integer status = (integer)defenses.z & ~COMBAT_MASK;
        store( <defenses.x, defenses.y, status>, DEFENSES );
        llSetTimerEvent( 0. );
    }
    
    run_time_permissions( integer perm )
    {
        if ( perm & PERMISSION_TAKE_CONTROLS ) {
            llTakeControls( CONTROL_FWD | CONTROL_BACK
               | CONTROL_LEFT | CONTROL_RIGHT
               | CONTROL_ROT_LEFT | CONTROL_ROT_RIGHT
               | CONTROL_LBUTTON | CONTROL_ML_LBUTTON,
               TRUE, TRUE );
        }
    }

    link_message( integer source, integer flags, string msg, key id )
    {
        if ( flags & COMBAT_LINK_MASK ) {
            list parsed = llParseString2List( msg, [ LINK_DELIM ], [] );
            string cmd = llList2String( parsed, 0 );
            
            // llOwnerSay( llGetScriptName() + ": " + msg );
        
            if ( cmd == "mode" ) {
                if ( llList2String( parsed, 1 ) == "combat" ) {
                    state fighting;
                }
            } else if ( cmd == "cmbt" ) {
                cmd = llList2String( parsed, 1 );
                if ( cmd == "aaim" ) {
                    autoAim = !autoAim;
                    if ( autoAim ) llOwnerSay( "Auto-aim on." );
                    else llOwnerSay( "Auto-aim off." );
                } else if ( cmd == "menu" ) {
                    combat_menu();
                }
            } else if ( cmd == "rset" ) {
                llResetScript();
            } else if ( cmd == "diag" ) {
                llWhisper( 0, "COMBAT\n" + (string)llGetFreeMemory()
                    + " bytes free"
                    + "\nStandby mode"
                    + "\nRanged command: " + rangedModeCommand
                    + "\nMelee command: " + meleeModeCommand
                    + "\nDefense command: " + defenseModeCommand
                    + "\nMelee Weapon stats: " + llList2CSV(meleeWeaponStats)
                    + "\nRanged Weapon stats: " + llList2CSV(rangeWeaponStats)
                    );
            } else if ( cmd == "fmem" ) {
                llMessageLinked( source, llGetFreeMemory(), "fmem", id );
            }
        }
    }
}

state fighting // == In combat =============================================
{
    state_entry()
    {
        if ( !( llGetPermissions() & PERMISSION_TAKE_CONTROLS ) ) {    
            llRequestPermissions( llGetOwner(), llGetPermissions() |
                PERMISSION_TAKE_CONTROLS );
        }
        vector defenses = retrieve( DEFENSES );
        integer status = (integer)defenses.z | COMBAT_MASK;
        store( <defenses.x, defenses.y, status>, DEFENSES );
        set_autoattack( autoAttack );
        llSleep( 0.1 );
        
        if ( attackMode == SAFE ) {
            set_default_combat_mode();
            // start_autoattack();
        }
    }
    
    run_time_permissions( integer perm )
    {
        if ( perm & PERMISSION_TAKE_CONTROLS ) {
            llTakeControls( CONTROL_FWD | CONTROL_BACK
               | CONTROL_LEFT | CONTROL_RIGHT
               | CONTROL_ROT_LEFT | CONTROL_ROT_RIGHT
               | CONTROL_LBUTTON | CONTROL_ML_LBUTTON,
               TRUE, TRUE );
        }
    }
   
    link_message( integer source, integer flags, string msg, key id )
    {
        if ( flags & COMBAT_LINK_MASK ) {
            // llOwnerSay( llGetScriptName() + ": " + msg );
            
            list parsed = llParseString2List( msg, [ LINK_DELIM ], [] );
            string cmd = llList2String( parsed, 0 );

            if ( cmd == "cmbt" ) {
                cmd = llList2String( parsed, 1 );
                integer power = flags & 0xFF;
                
                if ( cmd == "auto" ) {
                    set_autoattack( !autoAttack );
                    if ( !( meleePrim | rangePrim ) ) {
                        set_combat_mode( MELEE | RANGED );
                    }
                } else if ( cmd == "melee" ) {
                    set_combat_mode( MELEE );
                } else if ( cmd == "autoattack" ) {
                    cmd = llList2String( parsed, 2 );
                    if ( cmd == "suspend" ) {
                        autoAttackSuspend = TRUE;
                        llSetTimerEvent( 0. );
                    } else if ( cmd == "resume" ) {
                        autoAttackSuspend = FALSE;
                        if ( autoAttack ) {
                            llSetTimerEvent( minimum_attack_time() );
                        }
                    }
                } else if ( cmd == "defend" ) {
                    if ( !power ) {
                        if ( attackMode == DEFEND ) {
                            state default;
                        } else {
                            set_combat_mode( DEFEND );
                        }
                    }
                } else if ( cmd == "attack" ) {
                    if ( !power ) {
                        if ( attackMode & ( RANGED | MELEE ) ) {
                            state default;
                        } else {
                            set_default_combat_mode();
                        }
                    }
                } else if ( cmd == "ranged" ) {
                    set_combat_mode( RANGED );
                } else if ( cmd == "wpns" ) {
                    cmd = llList2String( parsed, 2 );
                    if ( cmd == "melee" ) {
                        meleeDelay = (float)llList2String( parsed, 3 );
                        meleeRange = (float)llList2String( parsed, 4 );
                        meleeWeaponStats = llList2List( parsed, 5, -1 );
                        meleeWeapon = id;
                    } else if ( cmd == "range" ) {
                        rangeDelay = (float)llList2String( parsed, 3 );
                        rangeRange = (float)llList2String( parsed, 4 );
                        rangeWeaponStats = llList2List( parsed, 5, -1 );
                        rangeWeapon = id;
                    }
                    if ( autoAttack ) {
                        llSetTimerEvent( minimum_attack_time() );
                    }
                } else if ( cmd == "action" ) {
                    if ( autoAttack ) {
                        llSetTimerEvent( minimum_attack_time() );
                    }
                } else if ( cmd == "ray" ) {
                    raycast_attack( (key)llList2String( parsed, 2 ) );
                }
            } else if ( cmd == "mode" ) {
                llMessageLinked( constructPrim,
                    CONSTRUCT_MASK,
                    llDumpList2String( [ "objt", "stmn", "off" ], 
                        LINK_DELIM ),
                    llGetOwner() );
                state default;
            } else if ( cmd == "rset" ) {
                llSleep( 10.0 );
                llResetScript();
            } else if ( cmd == "diag" ) {
                llWhisper( 0, "COMBAT\n" + (string)llGetFreeMemory()
                    + " bytes free"
                    + "\nFighting mode"
                    + "\nRanged command: " + rangedModeCommand
                    + "\nMelee command: " + meleeModeCommand
                    + "\nDefense command: " + defenseModeCommand
                    + "\nMelee Weapon stats: " + llList2CSV(meleeWeaponStats)
                    + "\nRanged Weapon stats: " + llList2CSV(rangeWeaponStats)
                    );
            } else if ( cmd == "fmem" ) {
                llMessageLinked( source, llGetFreeMemory(), "fmem", id );
            }
        }
    }
    
    control( key id, integer held, integer change )
    {
        if ( ~held & change & CONTROL_ML_LBUTTON ) {
            manual_attack( TRUE );
        } else if ( held & CONTROL_LBUTTON ) {
            if ( change & ~held & 
                ( CONTROL_ROT_LEFT | CONTROL_LEFT
                | CONTROL_ROT_RIGHT | CONTROL_RIGHT
                | CONTROL_FWD | CONTROL_BACK ) )
            {
                manual_attack( FALSE );
            }
        } else if ( held ) {
            if ( llGetAgentInfo(llGetOwner()) & 
                ( AGENT_ALWAYS_RUN | AGENT_FLYING ) )
            {
                autoAttackSuspend = TRUE;
            }
        } else if ( autoAttackSuspend ) {
            autoAttackSuspend = FALSE;
        }
    }
    
    timer()
    {
        if ( llGetObjectDesc() != NO_DAMAGE ) {
            llSetObjectDesc( NO_DAMAGE );
        }
        vector resources = retrieve( SMF );
        integer states = (integer)resources.x;
        if ( states & DEFEATED_MASK ) {
            set_autoattack( FALSE );
            set_combat_mode( DEFEND );
            return;
        }
        if ( autoAttack && !autoAttackSuspend && ( get_target() != NULL_KEY ) 
            && attackMode != DEFEND ) {
            auto_attack();
        }
    }
    
    sensor( integer d )
    {
        if ( get_target() == NULL_KEY ) {
            llMessageLinked( LINK_SET, BROADCAST_MASK, 
                llDumpList2String( [ "trgt", llDetectedKey(0) ], LINK_DELIM ),
                llGetOwner() );
        }
    }
}
