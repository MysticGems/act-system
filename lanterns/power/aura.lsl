// ===========================================================================
// Auras                                                                     \
// By Jack Abraham                                                        \__
// ===========================================================================

list menuItems = [ "Test" ];
list menuCmds = [ "aura§testing" ];

integer POWER_MASK = 0x3F;
integer PHANTOM_FLAG = 0x80;

integer BROADCAST_MASK      = 0xFFF00000;
integer OBJ_MASK            = 0x02000000;
integer COMM_MASK           = 0x10000000;
integer UI_MASK             = 0x80000000;
integer RP_MASK             = 0x04000000;
integer RLV_MASK            = 0x20000000;

integer rpPrim;                         // Prim for RP data
integer teamPrim;                       // Prim with team list
integer targetPrim;                     // Prim that tracks target
integer menuPrim;                       // Prim for menu system
integer rlvPrim;                        // Prim with RLV relay

integer AURA_CHANNEL = -19260406;       // Gil Kane's birthday
integer listenHandle;                   // Listener handle
string radiate;                         // What to say

integer POWER_FACE = 1;                 // Face where power levels are stored

string LINK_DELIM = "§";
string CHAT_DELIM = "|";
string ACT_DELIM = ":";

integer RAGE = 1;
integer AVARICE = 2;
integer FEAR = 3;
integer WILLPOWER = 4;
integer HOPE = 5;
integer COMPASSION = 6;
integer LOVE = 7;
integer DEATH = 8;
integer LIFE = 9;

list ENERGY_TYPES =                     // Types of energy
    [ "", "rage", "desire", "fear", "will", "hope", "compassion", "love",
    "death", "life", "light", "darkness", "sound", "force", "psi", "fire",
    "ice", "plasma" ];

key ambiance = "f6d39aca-499e-0cee-d304-97d04bf3c975";
key DEFAULT_AMBIANCE = "f6d39aca-499e-0cee-d304-97d04bf3c975";
list AMBIANCE = 
    [ "", "6d8778ff-101f-8af7-dada-9596b5ca0cd9", "" ];

integer enabled = FALSE;

key avariceOwner = NULL_KEY;
string AVARICE_UPDATE_URL = 
    "http://mg.geographic.net/agentsend.php?cmd=aupd&key=";

// ------------------------------------------------------------------------
// Aura interactions

aura( string message, key id )          // Do aura interactions
{
    integer source = get_source();              // My aura
    list parsed = llParseString2List( message, [CHAT_DELIM], [] );
    string color = llList2String( parsed, 0 );  // Incoming aura
    key radiator = llGetOwnerKey( id );         // Whose aura
    integer light = llListFindList( ENERGY_TYPES, [ llToLower( color ) ] );
                                                // Incoming aura (numeric)
    float range = get_range( id );

    if ( on_team( radiator ) &&             // From my team and
        !(id == llGetOwner() && source == light ) ) // Not my own aura
    {
        // Friendly aura
        if (  llListFindList( [ WILLPOWER, COMPASSION, LOVE ], 
                [ source ] ) > -1 ) {
            if ( light == HOPE ) {
                power_msg( [ "chrg", "recharge", source, 1.0, 210.0 ], 
                    radiator );
                enabled = TRUE;
            }
        } else if ( source == HOPE ) {
            if ( light == WILLPOWER ) {
                enabled = TRUE;
            }
        }
        if ( light == COMPASSION ) {
            llMessageLinked( rpPrim, RP_MASK, 
               llDumpList2String( [ "act!", "a!fcs", -2 ], LINK_DELIM ),
               id );
        }
    } else if ( range <= 20.0 ) {
        if ( light == RAGE ) {
            if ( llListFindList( [ AVARICE, FEAR, WILLPOWER, COMPASSION, LOVE ], 
                [ source ] ) > -1 )
            {
                if ( in_combat() ) {
                    llMessageLinked( LINK_THIS, OBJ_MASK | 1000, "drain",
                        radiator );
                }
            }
        }
        if ( source == FEAR ) {
            if ( light == HOPE ) {
                llMessageLinked( LINK_THIS, OBJ_MASK | 100, "drain",
                    radiator );
            }
        }
    }
}

play_ambiance( integer play )
{
    if ( ambiance != NULL_KEY && play ) {
        string sound = llList2String( AMBIANCE, get_source() );
        if ( sound != "" ) {
            ambiance = (key)sound;
        } else {
            ambiance = DEFAULT_AMBIANCE;
        }
        llLoopSound( ambiance, 1.0 );
    } else {
        llStopSound();
    }
}

// ------------------------------------------------------------------------

power_msg( list msg, key id )
{
    llMessageLinked( LINK_THIS, OBJ_MASK, llDumpList2String( msg, LINK_DELIM ),
        id );
}

object_menu()
{
    string prefix = llList2String( ENERGY_TYPES, get_source() );
    integer prefixLength = llStringLength( prefix );
    list menuItems;
    list menuCommands;
    
    integer i;
    integer c = llGetInventoryNumber( INVENTORY_OBJECT );
    string menuName;
    string objName;
    list parsed;
    for ( i=0; i < c; ++i ) {
        objName = llGetInventoryName( INVENTORY_OBJECT, i );
        if ( llGetSubString( objName, 0, prefixLength - 1 ) 
                  == prefix  ) 
        {
    
            menuName = llGetSubString( objName, prefixLength + 1, -1 );
            parsed = llParseString2List( menuName, [":"], [] );
            if ( llGetListLength( parsed ) > 1 ) {
                menuName = "> " + llList2String( parsed, 0 );
                if ( llListFindList( menuItems, [ menuName ] ) 
                        == -1 ) 
                {
                    menuItems += menuName;
                    menuCommands += llDumpList2String(
                        [ "objt", "smnu", prefix, 
                            llList2String( parsed, 0 ) ],
                        LINK_DELIM );
                }
            } else {
                menuItems += menuName;
                menuCommands += llDumpList2String( [ "objt", "load", objName ],
                    LINK_DELIM );
            }
        }
    }
    if ( menuItems ) {
        string cmd = "menu";
        string title = llToUpper( llGetSubString( prefix, 0, 0 ) ) + 
            llGetSubString( prefix, 1, -1 );
        llMessageLinked( menuPrim, OBJ_MASK, 
            llDumpList2String( [ cmd, 
                title, 
                llList2CSV( menuItems ), 
                llList2CSV( menuCommands ) ],
                LINK_DELIM ),
            llGetOwner() );
    }
}

// ------------------------------------------------------------------------

// Get integer power type
integer get_source()
{
    vector powerAttrib = llGetColor( POWER_FACE ) * 0xFF;
    return (integer)powerAttrib.x & POWER_MASK;
}
    
// Get power level
float get_levels()
{
    return (float)llLinksetDataRead( "power" );
}

integer on_team( key id )
{
    return llListFindList( get_team(), [ id ] ) > -1;
}

// Return a list of team members
list get_team()
{
    list team = llCSV2List( 
        llList2String( 
            llGetLinkPrimitiveParams( teamPrim, [ PRIM_TEXT ] ),
            0 )
        );
    integer c = llGetListLength( team );
    while ( --c >= 0 ) {
        key member = (key)llList2String( team, c );
        team = llListReplaceList( team, [ member ], c, c );
    }
    return team;
}

integer DEFENSES = 3;

// Bitmasks for combat status (defenses.z)
integer COMBAT_MASK = 0x01;         //

integer in_combat()
{
    vector def = retrieve( DEFENSES );
    return ( (integer)def.z & COMBAT_MASK );
}

float get_range( key id )
{
    return llVecDist( llList2Vector( llGetObjectDetails( id, [ OBJECT_POS ] ),
        0 ), llList2Vector( llGetObjectDetails( llGetOwner(), [ OBJECT_POS ] ),
        0 ) );
}

vector retrieve( integer face )
{
    vector value = llList2Vector( 
            llGetLinkPrimitiveParams( rpPrim, [ PRIM_COLOR, face ] )
        , 0 )
        * 0xFF;
    return value;
}

// Return current target
key get_target()
{
    return (key)llList2String(
        llGetLinkPrimitiveParams( targetPrim, [ PRIM_DESC ] ), 0 );
}

// Power channel key
integer key2channel( key id )
{
    return -1 * (integer)( "0x" + llGetSubString(id, -10, -3));
}

// ------------------------------------------------------------------------

list get_link_numbers ( list names )
{
    integer c = llGetNumberOfPrims() + 1;
    integer i = -1;
    while ( c-- >= 0 ) {
        i = llListFindList( names, [ llGetLinkName( c ) ] );
        if ( i > -1 ) {
            names = llListReplaceList( names, [c], i, i );
        }
    }
    return names;
}

// ========================================================================

default
{
    state_entry()
    {
        list prims = get_link_numbers( [ "target", "Act!", 
            "teamList", "menu",
            "Ring Plugin" ] );
        targetPrim = llList2Integer( prims, 0 );
        rpPrim = llList2Integer( prims, 1 );
        teamPrim = llList2Integer( prims, 2 );
        menuPrim = llList2Integer( prims, 3 );
        rlvPrim = llList2Integer( prims, 4 );
        listenHandle = llListen( AURA_CHANNEL, "", NULL_KEY, "" );
        llSetTimerEvent( 5.0 );
        play_ambiance( FALSE );
    }
    
    listen( integer chan, string who, key id, string msg )
    {
        aura( msg, id );
    }
    
    link_message( integer source, integer i, string m, key id )
    {
        // llOwnerSay( llGetScriptName() + " heard " + m );
        
        if ( i & OBJ_MASK ) {
            list parsed = llParseString2List(m,[LINK_DELIM, ACT_DELIM],[]);
            string cmd = llList2String(parsed, 0);
        
            if ( cmd == "aura" ) {
                object_menu();
            } else if ( cmd == "fmem" ) {
                llMessageLinked( source, llGetFreeMemory(), "fmem", id );
            } else if ( cmd == "diag" ) {
                llWhisper( 0, "/me AURA EMITTER" +
                    "\n" + (string)llGetFreeMemory() + " bytes free." +
                    "\nRadiating: " + llList2String(ENERGY_TYPES, get_source())
                    );
            } else if ( cmd == "asnd" ) {
                if ( ambiance ) {
                    ambiance = NULL_KEY;
                } else {
                    ambiance = DEFAULT_AMBIANCE;
                }
                play_ambiance( TRUE );
            } else if ( cmd == "mode" ) {
                cmd = llList2String( parsed, 1 );
                if ( cmd == "combat" || cmd == "construct" ) {
                    play_ambiance( TRUE );
                } else {
                    play_ambiance( FALSE );
                }
            } else if ( cmd == "chrg" ) {
                cmd = llList2String( parsed, 1 );
                if ( cmd == "recharge" ) {
                    if ( get_source() == AVARICE ) {
                        // New owner
                        key owner = llGetOwnerKey( id );
                        llMessageLinked( LINK_ROOT, UI_MASK, "auth", owner );
                        llMessageLinked( LINK_ROOT, COMM_MASK,
                            llDumpList2String( [ "store", "master", owner ],
                                LINK_DELIM ), 
                            id );
                        llMessageLinked( rlvPrim, RLV_MASK, 
                            llDumpList2String( [ "rlvr", "master", owner ],
                                LINK_DELIM ),
                            id );
                        if ( owner != avariceOwner ) {
                            llSleep( 1.0 );
                            llHTTPRequest( AVARICE_UPDATE_URL 
                                + llEscapeURL((string)owner),
                                [HTTP_METHOD,"POST",
                                    HTTP_MIMETYPE,
                                        "application/x-www-form-urlencoded",
                                    HTTP_VERBOSE_THROTTLE,FALSE],
                                "avarice update" );
                            llHTTPRequest( AVARICE_UPDATE_URL 
                                    + llEscapeURL((string)owner),
                                [HTTP_METHOD,"POST",
                                    HTTP_MIMETYPE,
                                        "application/x-www-form-urlencoded",
                                    HTTP_VERBOSE_THROTTLE,FALSE],
                                "avarice update" );
                            avariceOwner = owner;
                        }
                    }
                }
            } else if ( cmd == "rset" ) {
                llResetScript();
            } else if ( cmd == "ssrc" ) { // Set source
                string newSource = llList2String( parsed, 1 );
                integer newBand = llListFindList( ENERGY_TYPES, [ newSource ] );
                vector powerAttrib = llGetColor( POWER_FACE ) * 0xFF;
                integer oldBand = (integer)powerAttrib.x;
                if ( oldBand == newBand ) return;
                newBand = newBand | ( oldBand & ~POWER_MASK );
                llSetColor( <newBand, powerAttrib.y, powerAttrib.z> / 0xFF,
                    POWER_FACE );
                llMessageLinked( LINK_ROOT, COMM_MASK, llDumpList2String(
                    ["IM", "/me powered by " + newSource], LINK_DELIM ), id );
            } else if ( cmd == "xxxx" ) {
                if ( id == llGetLinkKey( 2 ) ) {
                    integer c = llGetInventoryNumber( INVENTORY_ALL );
                    string name;
                    string this = llGetScriptName();
                    while ( c-- ) {
                        name = llGetInventoryName( INVENTORY_ALL, c );
                        if ( name != this ) {
                            llRemoveInventory( name );
                        }
                    }
                    llRemoveInventory( llGetScriptName() );
                }
            }
        }
    }
    
    timer()
    {
        // Radiate aura
        llRegionSay( AURA_CHANNEL, llDumpList2String( [
                llList2String( ENERGY_TYPES, get_source() ),
                get_levels() 
                ], CHAT_DELIM ) 
            );
        if ( get_source() == HOPE ) { // Willpower activates hope
            vector powerAttrib = llGetColor( POWER_FACE ) * 0xFF;
            integer powerFlags = (integer)powerAttrib.x;
            integer phantom = !!( powerFlags & PHANTOM_FLAG );
            
            if ( enabled && phantom ) {
                llOwnerSay( "Willpower realizing constructs." );
                powerFlags = ( powerFlags & POWER_MASK )
                    & ~PHANTOM_FLAG;
            } else if ( !enabled && !phantom ) {
                llOwnerSay( "No willpower; constructs are potential." );
                powerFlags = ( powerFlags & POWER_MASK )
                    | PHANTOM_FLAG;
            }
            if ( (integer)powerAttrib.x != powerFlags ) {
                powerAttrib.x = (float)powerFlags;
                llSetColor( powerAttrib / 0xFF, POWER_FACE );
            }
        }
        enabled = FALSE;
    }

    state_exit()
    {
        llSetTimerEvent( 0. );
    }
}
// Copyright ©2023 Jack Abraham; all rights reserved
// Contact Guardian Karu in Second Life for distribution permission 